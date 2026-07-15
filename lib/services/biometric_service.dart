import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper around `local_auth` for the "Biometric Login" setting —
/// gates access to an already-persisted Firebase session (see
/// `BiometricLockScreen` / `SplashScreen`), it does not replace NIC+password
/// login itself.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True if the device has usable biometric hardware with at least one
  /// fingerprint/face enrolled.
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (e) {
      debugPrint('BiometricService.isAvailable error: $e');
      return false;
    }
  }

  /// Prompts the OS biometric dialog. Returns false on failure, cancellation,
  /// or any platform error rather than throwing.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('BiometricService.authenticate error: $e');
      return false;
    }
  }
}
