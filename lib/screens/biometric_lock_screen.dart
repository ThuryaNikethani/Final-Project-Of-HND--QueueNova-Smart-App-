import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:queuenova_mobile/services/biometric_service.dart';
import 'package:queuenova_mobile/screens/home_screen.dart';
import 'package:queuenova_mobile/screens/login_screen.dart';

/// Shown by SplashScreen instead of HomeScreen when the citizen has a valid
/// persisted session AND has "Biometric Login" enabled — the session itself
/// isn't gated by anything else, so this is what actually enforces the
/// setting instead of it being a no-op preference.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    setState(() => _isChecking = true);
    final ok = await BiometricService.authenticate('biometric_unlock_reason'.tr());
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('biometric_auth_failed'.tr()), backgroundColor: AppColors.error),
      );
    }
  }

  void _signInWithPassword() {
    Provider.of<AuthService>(context, listen: false).logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: const Icon(Icons.fingerprint, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  'biometric_unlock_title'.tr(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'biometric_unlock_prompt'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _tryUnlock,
                    icon: _isChecking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fingerprint),
                    label: Text('biometric_retry_button'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _signInWithPassword,
                  child: Text(
                    'biometric_use_password_button'.tr(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
