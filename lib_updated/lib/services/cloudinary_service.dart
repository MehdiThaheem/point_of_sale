import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Static configuration for the app's Cloudinary account.
///
/// [uploadPreset] must be an **unsigned** preset (Cloudinary dashboard →
/// Settings → Upload → Upload presets). Unsigned presets let the app
/// upload directly from the client without exposing an API secret, but
/// as a security trade-off Cloudinary will not allow certain params
/// (e.g. `overwrite`) to be sent from the client on this kind of preset —
/// see the note on [CloudinaryService.uploadImage] for how this service
/// works around that.
class CloudinaryConfig {
  const CloudinaryConfig._();

  static const String cloudName = 'mai49aep';
  static const String uploadPreset = 'companymanagement_project';
}

/// Why a Cloudinary upload failed, so callers can react appropriately
/// (e.g. show a "check your connection" message for [network], vs a
/// generic error for [server]) instead of just parsing the message text.
enum CloudinaryFailureReason {
  /// The file was rejected before any network request was made (e.g.
  /// empty bytes, or larger than [CloudinaryService.maxUploadBytes]).
  invalidInput,

  /// The request couldn't reach Cloudinary, or the connection dropped.
  network,

  /// The request took longer than [CloudinaryService.uploadTimeout].
  timeout,

  /// Cloudinary received the request but rejected it (bad preset,
  /// disallowed param, file too large per Cloudinary's own limits, etc).
  server,

  /// Cloudinary returned 200 but the response body wasn't what was
  /// expected (missing/empty `secure_url`, unparseable JSON).
  invalidResponse,
}

/// Thrown by [CloudinaryService.uploadImage] on any failure. [message] is
/// always safe to show directly to the user; [reason] and [statusCode]
/// are there for callers that want to branch on the failure type.
class CloudinaryUploadException implements Exception {
  final String message;
  final CloudinaryFailureReason reason;
  final int? statusCode;

  const CloudinaryUploadException(
      this.message, {
        this.reason = CloudinaryFailureReason.server,
        this.statusCode,
      });

  @override
  String toString() => message;
}

/// Uploads images to Cloudinary using the app's unsigned upload preset.
///
/// This talks to Cloudinary's HTTP upload API directly — no API secret
/// is used or needed, which is what makes it safe to call from the
/// Flutter app (web included) rather than from a trusted server.
class CloudinaryService {
  const CloudinaryService();

  /// Cloudinary's own hard limit for unsigned/free-tier image uploads is
  /// 10 MB; failing fast client-side avoids a slow round trip just to
  /// get the same rejection back from the server.
  static const int maxUploadBytes = 10 * 1024 * 1024;

  static const Duration uploadTimeout = Duration(seconds: 30);

  static Uri get _endpoint => Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload');

  /// Uploads [bytes] as an image and returns its `secure_url`.
  ///
  /// [folder] groups the asset under a Cloudinary folder (e.g.
  /// `'profile_photos'`); purely organizational.
  ///
  /// [publicId], if given, is used as the base of the asset's public ID
  /// — but a timestamp is always appended to it internally to keep it
  /// unique. This is intentional, not a fallback: Cloudinary's unsigned
  /// presets are not allowed to overwrite an existing asset (it rejects
  /// `overwrite: true` outright for security reasons), so re-using the
  /// exact same public ID for a re-upload would either fail or silently
  /// keep serving the old file from cache. Making every upload's ID
  /// unique sidesteps both problems at once: there's never anything to
  /// overwrite, and the returned URL is always new, so neither
  /// Cloudinary's CDN nor Flutter's own image cache can ever show a
  /// stale picture. The trade-off is that old assets aren't deleted —
  /// deleting from Cloudinary requires a signed request (i.e. a backend
  /// holding the API secret), which is out of scope for a client-only
  /// setup like this one.
  ///
  /// Throws [CloudinaryUploadException] on any failure — see
  /// [CloudinaryFailureReason] for how to distinguish failure types.
  Future<String> uploadImage(
      Uint8List bytes, {
        String? folder,
        String? publicId,
      }) async {
    if (bytes.isEmpty) {
      throw const CloudinaryUploadException(
        'Selected file is empty.',
        reason: CloudinaryFailureReason.invalidInput,
      );
    }
    if (bytes.length > maxUploadBytes) {
      final mb = (maxUploadBytes / (1024 * 1024)).toStringAsFixed(0);
      throw CloudinaryUploadException(
        'Image is too large — please choose one under ${mb}MB.',
        reason: CloudinaryFailureReason.invalidInput,
      );
    }

    final request = http.MultipartRequest('POST', _endpoint)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset;

    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }

    if (publicId != null && publicId.isNotEmpty) {
      request.fields['public_id'] = _uniquePublicId(publicId);
    }

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: 'upload.jpg'),
    );

    late final http.Response response;
    try {
      final streamedResponse = await request.send().timeout(uploadTimeout);
      response = await http.Response.fromStream(streamedResponse);
    } on TimeoutException {
      throw CloudinaryUploadException(
        'Upload timed out after ${uploadTimeout.inSeconds}s — '
            'check your connection and try again.',
        reason: CloudinaryFailureReason.timeout,
      );
    } catch (e) {
      throw CloudinaryUploadException(
        'Could not reach Cloudinary: $e',
        reason: CloudinaryFailureReason.network,
      );
    }

    if (response.statusCode != 200) {
      throw CloudinaryUploadException(
        'Cloudinary upload failed: ${_extractErrorMessage(response.body)}',
        reason: CloudinaryFailureReason.server,
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const CloudinaryUploadException(
        'Cloudinary returned an unreadable response.',
        reason: CloudinaryFailureReason.invalidResponse,
      );
    }

    final url = data['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw const CloudinaryUploadException(
        'Cloudinary upload succeeded but no URL was returned.',
        reason: CloudinaryFailureReason.invalidResponse,
      );
    }

    return url;
  }

  /// Keeps only characters Cloudinary allows in a public ID and appends
  /// a millisecond timestamp so the ID is always unique (see the
  /// [uploadImage] doc comment for why that matters). Without this,
  /// a name like "Hassan Khan" would also get mangled by Cloudinary's
  /// own sanitization in less predictable ways.
  String _uniquePublicId(String base) {
    final safeBase =
    base.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${safeBase}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Cloudinary error bodies are normally
  /// `{"error": {"message": "..."}}`, but this falls back to the raw
  /// body for any response that doesn't match that shape rather than
  /// throwing a second, more confusing exception while handling the
  /// first one.
  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final message = decoded['error']['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Fall through to the raw body below.
    }
    return body;
  }
}