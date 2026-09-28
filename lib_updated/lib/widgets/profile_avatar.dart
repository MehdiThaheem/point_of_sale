import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../services/user_service.dart';

// A circular profile picture that the user can tap to change.
// Uploads to Cloudinary under the "profile_photos" folder (public_id =
// the user's uid, so re-uploading replaces the old photo) and saves the
// resulting URL to the user's Firestore profile.
class ProfileAvatar extends StatefulWidget {
  final String uid;
  final String? photoUrl;
  final double radius;
  final Color badgeColor;

  const ProfileAvatar({
    super.key,
    required this.uid,
    this.photoUrl,
    this.radius = 32,
    this.badgeColor = Colors.orange,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  final UserService _userService = UserService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _uploading = false;
  String? _localUrl;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final XFile? picked;

    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 80,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open gallery: $e')),
        );
      }
      return;
    }

    if (picked == null) return;

    setState(() => _uploading = true);

    try {
      final bytes = await picked.readAsBytes();
      final url = await _cloudinaryService.uploadImage(
        bytes,
        folder: 'profile_photos',
        publicId: widget.uid,
      );

      await _userService.updatePhotoUrl(uid: widget.uid, photoUrl: url);

      if (mounted) {
        // Cache-bust: Flutter's NetworkImage cache (and the browser's)
        // key images by URL. If Cloudinary ever returns the same URL
        // for the new photo as the old one, the app would keep showing
        // the old picture from cache even though the upload succeeded.
        // Appending a changing query param guarantees a fresh fetch.
        final bustUrl =
            '$url${url.contains('?') ? '&' : '?'}v=${DateTime.now().millisecondsSinceEpoch}';
        setState(() => _localUrl = bustUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _localUrl ?? widget.photoUrl;
    final hasPhoto = url != null && url.isNotEmpty;

    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: SizedBox(
        width: widget.radius * 2 + 8,
        height: widget.radius * 2 + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: widget.radius,
              backgroundColor: Colors.white24,
              backgroundImage: hasPhoto ? NetworkImage(url) : null,
              child: !hasPhoto
                  ? Icon(Icons.person_outline, size: widget.radius)
                  : null,
            ),
            if (_uploading)
              Positioned.fill(
                child: CircleAvatar(
                  radius: widget.radius,
                  backgroundColor: Colors.black38,
                  child: SizedBox(
                    width: widget.radius * 0.6,
                    height: widget.radius * 0.6,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: widget.radius * 0.4,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}