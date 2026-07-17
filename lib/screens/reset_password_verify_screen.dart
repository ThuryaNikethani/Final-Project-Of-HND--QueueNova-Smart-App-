import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:queuenova_mobile/screens/login_screen.dart';
import 'package:provider/provider.dart';

/// Step 2 of the forgot-password flow: verifies the code AuthService emailed
/// in ForgotPasswordScreen. On success the backend has already updated the
/// Firebase Auth password (see AuthService.confirmPasswordReset) — this
/// screen just reports that and sends the citizen back to log in with it.
class ResetPasswordVerifyScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String newPassword;

  const ResetPasswordVerifyScreen({super.key, required this.uid, required this.email, required this.newPassword});

  @override
  State<ResetPasswordVerifyScreen> createState() => _ResetPasswordVerifyScreenState();
}

class _ResetPasswordVerifyScreenState extends State<ResetPasswordVerifyScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('otp_code_required'.tr()), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isVerifying = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.confirmPasswordReset(uid: widget.uid, code: code);
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('password_reset_successful'.tr()), backgroundColor: AppColors.success),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('invalid_reset_code'.tr()), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.resendPasswordResetCode(uid: widget.uid, email: widget.email, newPassword: widget.newPassword);
    if (!mounted) return;
    setState(() => _isResending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'reset_code_resent'.tr() : 'reset_code_resend_failed'.tr()),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reset_password_verify_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: const Center(child: Icon(Icons.mark_email_read_outlined, size: 35, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'reset_password_verify_title'.tr(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'reset_code_sent_to'.tr(args: [widget.email]),
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'otp_enter_code_hint'.tr(),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isVerifying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('verify_and_reset'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _isResending ? null : _resend,
                child: _isResending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('resend_code'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
