import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:queuenova_mobile/services/image_moderation_service.dart';

class EditProfilePictureScreen extends StatefulWidget {
  const EditProfilePictureScreen({super.key});

  @override
  State<EditProfilePictureScreen> createState() =>
      _EditProfilePictureScreenState();
}

class _EditProfilePictureScreenState extends State<EditProfilePictureScreen> {
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    // Compress to ≤400×400 at 60% quality so the base64 string fits in Firestore
    final file = await picker.pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (file == null || !mounted) return;

    // Capture context-dependent objects before any async gap
    final authService = Provider.of<AuthService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);
    try {
      final bytes = await file.readAsBytes();

      // Block anything flagged as inappropriate before it's ever uploaded.
      // Bounded so a slow/unreachable moderation service can't hang the UI.
      final moderation = await ImageModerationService.checkImage(bytes)
          .timeout(const Duration(seconds: 12), onTimeout: () => const ModerationResult(safe: true, checked: false));
      if (!moderation.safe) {
        if (mounted) setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('photo_inappropriate_error'.tr()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Upload to Firebase Storage and save the resulting download link,
      // replacing any previously saved photo. Bounded so a stuck upload
      // always resolves to a visible error instead of spinning forever.
      final success = await authService.uploadProfilePhoto(bytes).timeout(const Duration(seconds: 30));
      if (!success) throw Exception('Upload failed');

      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('profile_picture_updated'.tr()),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      navigator.pop(true);
    } on TimeoutException {
      debugPrint('Profile picture upload timed out');
      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('upload_timed_out'.tr()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Profile picture save failed: $e');
      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('failed_save_photo'.tr()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeProfilePicture() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('remove_profile_picture_title'.tr()),
        content: Text('remove_profile_picture_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (!mounted) return;

              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              setState(() => _isLoading = true);
              try {
                await authService.updateProfilePhoto(null).timeout(const Duration(seconds: 15));
                if (mounted) setState(() => _isLoading = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('profile_picture_removed'.tr()),
                    backgroundColor: AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                navigator.pop(true);
              } catch (e) {
                debugPrint('Profile picture removal failed: $e');
                if (mounted) setState(() => _isLoading = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('failed_remove_photo'.tr()),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('remove_button'.tr()),
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// Shows the profile image from a base64 string, URL, or falls back to initials.
  Widget _buildPhotoWidget(String? photoData, String? name, double size) {
    if (photoData == null) {
      return Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.32,
              fontWeight: FontWeight.bold),
        ),
      );
    }
    try {
      final bytes = base64Decode(photoData);
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Text(_getInitials(name),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.bold)),
        ),
      );
    } catch (_) {
      // Fallback for plain URLs
      return Image.network(
        photoData,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Text(_getInitials(name),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final photoData = authService.userPhotoUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text('profile_picture_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (photoData != null)
            TextButton(
              onPressed: _removeProfilePicture,
              child: Text(
                'remove_button'.tr(),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildPhotoWidget(
                          photoData, authService.userName, 150),
                    ),
                  ),
                  if (_isLoading)
                    Container(
                      width: 150,
                      height: 150,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'choose_option_update_photo'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOptionCard(
                          icon: Icons.camera_alt,
                          title: 'camera_option'.tr(),
                          subtitle: 'take_a_photo'.tr(),
                          color: AppColors.primaryBlue,
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildOptionCard(
                          icon: Icons.photo_library,
                          title: 'gallery_option'.tr(),
                          subtitle: 'choose_from_gallery'.tr(),
                          color: AppColors.success,
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'profile_picture_visibility_note'.tr(),
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.primaryBlue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
