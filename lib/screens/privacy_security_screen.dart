import 'package:flutter/material.dart';
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
        return 'Deletion request pending officer review';
      case 'approved':
        return 'Request approved — tap to delete or deactivate';
      case 'rejected':
        return 'Previous request rejected — tap for details';
      default:
        return 'Permanently delete your account and all data';
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
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your request will be reviewed by an officer before your account can be deleted or deactivated.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              final reason = reasonController.text.trim();
              await authService.submitAccountDeletionRequest(
                reason: reason.isEmpty ? null : reason,
              );
              await _loadDeletionRequestStatus();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Account deletion request submitted'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Submit Request'),
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
        title: const Text('Request Pending'),
        content: const Text('Your account deletion request is awaiting review by an officer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRejectedDialog() {
    final reason = _deletionRequest?['rejectionReason'] as String? ?? 'No reason provided';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Rejected'),
        content: Text('Your previous deletion request was rejected:\n\n$reason'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showRequestDeletionDialog();
            },
            child: const Text('Submit New Request'),
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
        title: const Text('Request Approved'),
        content: const Text(
          'An officer has approved your request. Choose how to proceed:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _confirmFinalAction(permanentDelete: false);
            },
            child: const Text('Deactivate'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _confirmFinalAction(permanentDelete: true);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete Permanently'),
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
        title: Text(permanentDelete ? 'Delete Account Permanently' : 'Deactivate Account'),
        content: Text(
          permanentDelete
              ? 'This will permanently delete your account and all data. This cannot be undone.'
              : 'This will deactivate your account and sign you out. Your data is kept but you will not be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
            child: Text(permanentDelete ? 'Delete' : 'Deactivate'),
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
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed successfully'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Security Section
            _buildSectionHeader('Security', Icons.security_rounded),
            _buildSwitchTile(
              'Biometric Login',
              'Use fingerprint or face recognition to login',
              Icons.fingerprint,
              isBiometricEnabled,
              (value) {
                setState(() => isBiometricEnabled = value);
                _saveSetting('biometric_enabled', value);
              },
            ),
            _buildSwitchTile(
              'Two-Factor Authentication',
              'Receive OTP for secure login',
              Icons.sms_rounded,
              isTwoFactorEnabled,
              (value) {
                setState(() => isTwoFactorEnabled = value);
                _saveSetting('two_factor_enabled', value);
              },
            ),
            _buildActionTile(
              'Change Password',
              'Update your account password',
              Icons.lock_reset_rounded,
              _changePassword,
            ),
            
            const SizedBox(height: 8),
            // Privacy Section
            _buildSectionHeader('Privacy', Icons.privacy_tip_rounded),
            _buildSwitchTile(
              'Push Notifications',
              'Receive alerts about queue updates and appointments',
              Icons.notifications_rounded,
              isNotificationEnabled,
              (value) {
                setState(() => isNotificationEnabled = value);
                _saveSetting('notifications_enabled', value);
              },
            ),
            _buildSwitchTile(
              'Location Access',
              'Allow app to suggest nearby offices',
              Icons.location_on_rounded,
              isLocationEnabled,
              (value) {
                setState(() => isLocationEnabled = value);
                _saveSetting('location_enabled', value);
              },
            ),
            _buildActionTile(
              'Data Download',
              'Request a copy of your personal data',
              Icons.download_rounded,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data download request submitted'), backgroundColor: AppColors.success),
                );
              },
            ),
            _buildActionTile(
              'Delete Account',
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
                  _buildInfoRow('App Version', '1.0.0'),
                  _buildInfoRow('Last Updated', 'May 2026'),
                  _buildInfoRow('Privacy Policy', 'View Policy', isLink: true),
                  _buildInfoRow('Terms of Service', 'View Terms', isLink: true),
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