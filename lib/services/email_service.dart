import 'dart:convert';
import 'package:http/http.dart' as http;

/// Account-specific EmailJS settings.
///
/// To make this work:
/// 1. Create a free account at https://emailjs.com
/// 2. Email Services -> Add an email service (e.g. your Gmail) -> copy
///    its Service ID into [serviceId] below.
/// 3. Email Templates -> create a template with these variables in the
///    body: {{employee_name}}, {{username}}, {{password}}, {{role}} —
///    and set the template's "To email" field to {{to_email}}. Copy
///    its Template ID into [templateId].
/// 4. Account -> General -> copy your Public Key into [publicKey].
/// 5. Account -> Security -> if this app runs outside a browser
///    (Android/iOS/desktop, not just Flutter web), turn ON "Allow
///    EmailJS API for non-browser applications" — EmailJS blocks
///    non-browser requests by default.
class EmailJsConfig {
  const EmailJsConfig._();

  static const String serviceId = 'service_6t586q6';
  static const String templateId = 'template_zjfxzaj';
  static const String publicKey = 'CfwQzbQJ87ZRidWz4';

  static bool get isConfigured =>
      serviceId != 'YOUR_SERVICE_ID' &&
          templateId != 'YOUR_TEMPLATE_ID' &&
          publicKey != 'YOUR_PUBLIC_KEY';
}

class EmailService {
  const EmailService();

  static final Uri _endpoint =
  Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

  /// Emails [toEmail] their new portal [username] and [password].
  ///
  /// SECURITY NOTE: sending a password as plain text in an email is
  /// convenient, but if that inbox is ever compromised the password is
  /// exposed right along with it — and many people reuse passwords
  /// elsewhere, so the exposure isn't limited to this app. The safer
  /// alternative already built into this app is the "Send Password
  /// Reset Email" button on Manage Account, which only ever emails a
  /// link, never the password itself. This method exists because it
  /// was explicitly requested; worth switching to the reset-link flow
  /// later if that risk matters for this business.
  ///
  /// Returns true if EmailJS accepted the request. Never throws — a
  /// failed email shouldn't be treated as a failed account creation,
  /// so callers just check the boolean.
  Future<bool> sendLoginCredentials({
    required String toEmail,
    required String employeeName,
    required String username,
    required String password,
    required String roleLabel,
  }) async {
    if (!EmailJsConfig.isConfigured) {
      // Not set up yet — see the setup steps on EmailJsConfig above.
      return false;
    }
    try {
      final response = await http
          .post(
        _endpoint,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': EmailJsConfig.serviceId,
          'template_id': EmailJsConfig.templateId,
          'user_id': EmailJsConfig.publicKey,
          'template_params': {
            'to_email': toEmail,
            'employee_name': employeeName,
            'username': username,
            'password': password,
            'role': roleLabel,
          },
        }),
      )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}