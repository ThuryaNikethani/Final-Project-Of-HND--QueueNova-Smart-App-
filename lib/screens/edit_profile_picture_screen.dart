import 'dart:convert';
import 'package:flutter/material.dart';
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
      final moderation = await ImageModerationService.checkImage(bytes);
      if (!moderation.safe) {
        if (mounted) setState(() => _isLoading = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This photo looks inappropriate and cannot be used as your profile picture. Please choose another one.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Upload to Firebase Storage and save the resulting download link,
      // replacing any previously saved photo.
      final success = await authService.uploadProfilePhoto(bytes);
      if (!success) throw Exception('Upload failed');

      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      navigator.pop(true);
    } catch (e) {
      debugPrint('Profile picture save failed: $e');
      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to save photo. Please try again.'),
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
        title: const Text('Remove Profile Picture'),
        content: const Text(
            'Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
              await authService.updateProfilePhoto(null);
              if (mounted) setState(() => _isLoading = false);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Profile picture removed'),
                  backgroundColor: AppColors.warning,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              navigator.pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
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
        title: const Text('Profile Picture'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (photoData != null)
            TextButton(
              onPressed: _removeProfilePicture,
              child: const Text(
                'Remove',
                style: TextStyle(color: AppColors.error),
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
                  const Text(
                    'Choose an option to update your profile picture',
                    style: TextStyle(
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
                          title: 'Camera',
                          subtitle: 'Take a photo',
                          color: AppColors.primaryBlue,
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildOptionCard(
                          icon: Icons.photo_library,
                          title: 'Gallery',
                          subtitle: 'Choose from gallery',
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
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your profile picture will be visible to government officers when you visit service centers.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.primaryBlue),
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
