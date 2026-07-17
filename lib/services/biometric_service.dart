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
  ///
  /// [AuthenticationOptions.biometricOnly] is false rather than true: Android
  /// maps `biometricOnly: true` to BIOMETRIC_STRONG-only, which rejects
  /// Samsung's Face Recognition (registered as a weak/convenience biometric,
  /// Class 1, since it's easier to spoof than fingerprint) even when it's
  /// enrolled and working fine at the OS lock-screen level. Allowing weak
  /// biometrics also means Android permits device PIN/pattern/password as a
  /// fallback — the two can't be separated in the platform API — which is an
  /// acceptable tradeoff since this only gates re-entry to an already
  /// Firebase-authenticated session, not the citizen's actual credentials.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('BiometricService.authenticate error: $e');
      return false;
    }
  }
}
