import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:queuenova_mobile/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool isBiometricEnabled = false;
  bool isTwoFactorEnabled = false;
  bool isNotificationEnabled = true;
  bool isLocationEnabled = true;
  Map<String, dynamic>? _deletionRequest;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDeletionRequestStatus();
  }

  Future<void> _loadDeletionRequestStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final status = await authService.getAccountDeletionRequestStatus();
    if (!mounted) return;
    setState(() => _deletionRequest = status);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      isTwoFactorEnabled = prefs.getBool('two_factor_enabled') ?? false;
      isNotificationEnabled = prefs.getBool('notifications_enabled') ?? true;
      isLocationEnabled = prefs.getBool('location_enabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  String _deletionTileSubtitle() {
    switch (_deletionRequest?['status']) {
      case 'pending':
        return 'deletion_pending_subtitle'.tr();
      case 'approved':
        return 'deletion_approved_subtitle'.tr();
      case 'rejected':
        return 'deletion_rejected_subtitle'.tr();
      default:
        return 'deletion_default_subtitle'.tr();
    }
  }

  void _openDeleteAccountFlow() {
    switch (_deletionRequest?['status']) {
      case 'pending':
        _showPendingDialog();
        break;
      case 'approved':
        _showApprovedActionDialog();
        break;
      case 'rejected':
        _showRejectedDialog();
        break;
      default:
        _showRequestDeletionDialog();
    }
  }

  void _showRequestDeletionDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('delete_account'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'deletion_review_notice'.tr(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'reason_optional_label'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              final reason = reasonController.text.trim();
              final success = await authService.submitAccountDeletionRequest(
                reason: reason.isEmpty ? null : reason,
              );
              await _loadDeletionRequestStatus();
              final message = success
                  ? 'deletion_request_submitted'.tr()
                  : switch (authService.lastDeletionRequestError) {
                      'already_pending' => 'deletion_already_pending'.tr(),
                      'not_signed_in' => 'must_be_signed_in'.tr(),
                      _ => 'submit_request_failed'.tr(),
                    };
              messenger.showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: success ? AppColors.success : AppColors.error,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('submit_request_button'.tr()),
          ),
        ],
      ),
    );
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('request_pending_title'.tr()),
        content: Text('deletion_awaiting_review'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showRejectedDialog() {
    final reason = _deletionRequest?['rejectionReason'] as String? ?? 'no_reason_provided'.tr();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('request_rejected_title'.tr()),
        content: Text('deletion_rejected_reason'.tr(args: [reason])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('close'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showRequestDeletionDialog();
            },
            child: Text('submit_new_request'.tr()),
          ),
        ],
      ),
    );
  }

  void _showApprovedActionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('request_approved_title'.tr()),
        content: Text(
          'deletion_approved_notice'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _confirmFinalAction(permanentDelete: false);
            },
            child: Text('deactivate_button'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _confirmFinalAction(permanentDelete: true);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('delete_permanently_button'.tr()),
          ),
        ],
      ),
    );
  }

  void _confirmFinalAction({required bool permanentDelete}) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(permanentDelete ? 'delete_account_permanently_title'.tr() : 'deactivate_account_title'.tr()),
        content: Text(
          permanentDelete
              ? 'delete_permanently_warning'.tr()
              : 'deactivate_warning'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final navigator = Navigator.of(context);
              Navigator.pop(dialogContext);
              await authService.finalizeAccountDeletion(
                requestId: _deletionRequest!['id'] as String,
                permanentDelete: permanentDelete,
              );
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(permanentDelete ? 'delete_button'.tr() : 'deactivate_button'.tr()),
          ),
        ],
      ),
    );
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('change_password'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'current_password_label'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'new_password_label'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'confirm_new_password_label'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('password_changed_successfully'.tr()), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: Text('update_button'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('privacy_security'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Security Section
            _buildSectionHeader('security_section'.tr(), Icons.security_rounded),
            _buildSwitchTile(
              'biometric_login'.tr(),
              'biometric_login_desc'.tr(),
              Icons.fingerprint,
              isBiometricEnabled,
              (value) {
                setState(() => isBiometricEnabled = value);
                _saveSetting('biometric_enabled', value);
              },
            ),
            _buildSwitchTile(
              'two_factor_auth'.tr(),
              'two_factor_auth_desc'.tr(),
              Icons.sms_rounded,
              isTwoFactorEnabled,
              (value) {
                setState(() => isTwoFactorEnabled = value);
                _saveSetting('two_factor_enabled', value);
              },
            ),
            _buildActionTile(
              'change_password'.tr(),
              'change_password_desc'.tr(),
              Icons.lock_reset_rounded,
              _changePassword,
            ),

            const SizedBox(height: 8),
            // Privacy Section
            _buildSectionHeader('privacy_section'.tr(), Icons.privacy_tip_rounded),
            _buildSwitchTile(
              'push_notifications'.tr(),
              'push_notifications_desc'.tr(),
              Icons.notifications_rounded,
              isNotificationEnabled,
              (value) {
                setState(() => isNotificationEnabled = value);
                _saveSetting('notifications_enabled', value);
              },
            ),
            _buildSwitchTile(
              'location_access'.tr(),
              'location_access_desc'.tr(),
              Icons.location_on_rounded,
              isLocationEnabled,
              (value) {
                setState(() => isLocationEnabled = value);
                _saveSetting('location_enabled', value);
              },
            ),
            _buildActionTile(
              'data_download'.tr(),
              'data_download_desc'.tr(),
              Icons.download_rounded,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('data_download_submitted'.tr()), backgroundColor: AppColors.success),
                );
              },
            ),
            _buildActionTile(
              'delete_account'.tr(),
              _deletionTileSubtitle(),
              Icons.delete_forever_rounded,
              _openDeleteAccountFlow,
              isDanger: true,
            ),

            const SizedBox(height: 24),
            // App Info
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildInfoRow('app_version_label'.tr(), '1.0.0'),
                  _buildInfoRow('last_updated_label'.tr(), 'May 2026'),
                  _buildInfoRow('privacy_policy_label'.tr(), 'view_policy_label'.tr(), isLink: true),
                  _buildInfoRow('terms_of_service_label'.tr(), 'view_terms_label'.tr(), isLink: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isDanger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDanger ? AppColors.error : AppColors.lightBlue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: isDanger ? AppColors.error : AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDanger ? AppColors.error : null)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.grey)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: isDanger ? AppColors.error : AppColors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.grey)),
          Text(
            value,
            style: TextStyle(
              color: isLink ? AppColors.primaryBlue : AppColors.textPrimary,
              decoration: isLink ? TextDecoration.underline : null,
            ),
          ),
        ],
      ),
    );
  }
}