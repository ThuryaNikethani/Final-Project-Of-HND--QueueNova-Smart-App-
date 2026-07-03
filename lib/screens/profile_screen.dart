import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:queuenova_mobile/screens/login_screen.dart';
import 'package:queuenova_mobile/screens/personal_info_screen.dart';
import 'package:queuenova_mobile/screens/my_documents_screen.dart';
import 'package:queuenova_mobile/screens/service_history_screen.dart';
import 'package:queuenova_mobile/screens/notifications_screen.dart';
import 'package:queuenova_mobile/screens/language_screen.dart';
import 'package:queuenova_mobile/screens/privacy_security_screen.dart';
import 'package:queuenova_mobile/screens/edit_profile_picture_screen.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// Renders a profile image from a base64 string (or URL fallback), or shows initials.
  Widget _buildPhotoWidget(String? photoData, String? name, double size) {
    final initials = Center(
      child: Text(
        _getInitials(name),
        style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold),
      ),
    );
    if (photoData == null) return initials;
    try {
      final bytes = base64Decode(photoData);
      return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => initials);
    } catch (_) {
      return Image.network(photoData, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => initials);
    }
  }

  Future<void> _navigateToEditPicture(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const EditProfilePictureScreen()),
    );
    // No result handling needed — AuthService.updateProfilePhoto() calls
    // notifyListeners(), so this screen rebuilds automatically via Provider.
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'profile'.tr(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Avatar with Edit Icon
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _navigateToEditPicture(context),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildPhotoWidget(
                            authService.userPhotoUrl,
                            authService.userName,
                            110),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _navigateToEditPicture(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              authService.userName ?? '',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              authService.userNIC ?? 'NIC not set',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                authService.userRole?.toUpperCase() ?? 'CITIZEN',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Profile Menu Items
            _buildMenuItem(
              context,
              icon: Icons.person_outline,
              title: 'personal_information'.tr(),
              subtitle: 'update_personal_details'.tr(),
              screen: const PersonalInfoScreen(),
            ),
            _buildMenuItem(
              context,
              icon: Icons.document_scanner_outlined,
              title: 'my_documents'.tr(),
              subtitle: 'view_uploaded_documents'.tr(),
              screen: const MyDocumentsScreen(),
            ),
            _buildMenuItem(
              context,
              icon: Icons.history,
              title: 'service_history'.tr(),
              subtitle: 'view_past_requests'.tr(),
              screen: const ServiceHistoryScreen(),
            ),
            _buildMenuItem(
              context,
              icon: Icons.notifications_none,
              title: 'notifications'.tr(),
              subtitle: 'manage_notification_preferences'.tr(),
              screen: const NotificationsScreen(),
            ),
            _buildMenuItem(
              context,
              icon: Icons.language,
              title: 'language'.tr(),
              subtitle: 'sinhala_tamil_english'.tr(),
              screen: const LanguageScreen(),
            ),
            _buildMenuItem(
              context,
              icon: Icons.security_outlined,
              title: 'privacy_security'.tr(),
              subtitle: 'change_password_privacy_settings'.tr(),
              screen: const PrivacySecurityScreen(),
            ),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Row(
                        children: [
                          const Icon(Icons.logout, color: AppColors.error),
                          const SizedBox(width: 10),
                          Text(
                            'logout'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        'are_you_sure_logout'.tr(),
                        style: const TextStyle(fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          child: Text(
                            'cancel'.tr(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          child: Text(
                            'logout'.tr(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await authService.logout();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'logout'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),

            // App Version
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    'QueueNova v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© 2026 QueueNova. All rights reserved.',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.grey.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.grey,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ),
    );
  }
}
