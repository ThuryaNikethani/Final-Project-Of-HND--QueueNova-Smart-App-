import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:queuenova_mobile/screens/home_screen.dart';

/// Shown after login() when the citizen's `two_factor_enabled` preference is
/// on. Verifies the OTP AuthService already sent via SMS before completing
/// the sign-in (isAuthenticated stays false until this succeeds).
class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final String email;

  const OtpVerificationScreen({super.key, required this.phone, this.email = ''});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
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
    final success = await authService.verifyTwoFactorCode(code);
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      final message = switch (authService.lastLoginError) {
        'otp_expired' => 'otp_expired'.tr(),
        _ => 'otp_invalid_code'.tr(),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.resendTwoFactorCode();
    if (!mounted) return;
    setState(() => _isResending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('otp_resend_success'.tr()), backgroundColor: AppColors.success),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.sms_rounded, size: 44, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'otp_verification_title'.tr(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email.isNotEmpty
                    ? 'otp_sent_to_both'.tr(args: [widget.phone, widget.email])
                    : 'otp_sent_to'.tr(args: [widget.phone]),
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'otp_enter_code_hint'.tr(),
                  filled: true,
                  fillColor: AppColors.surface,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
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
                      : Text('otp_verify_button'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isResending ? null : _resend,
                  child: Text('otp_resend_code'.tr(), style: const TextStyle(color: AppColors.primaryBlue)),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    Provider.of<AuthService>(context, listen: false).cancelTwoFactorLogin();
                    Navigator.pop(context);
                  },
                  child: Text('otp_use_password_instead'.tr(), style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
