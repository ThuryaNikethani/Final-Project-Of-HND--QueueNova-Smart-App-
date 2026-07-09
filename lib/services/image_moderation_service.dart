import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';

class ModerationResult {
  final bool safe;
  final List<String> reasons;
  final bool checked;

  const ModerationResult({required this.safe, this.reasons = const [], required this.checked});
}

/// Checks images for inappropriate content via the backend's Google Cloud
/// Vision SafeSearch proxy before they're accepted as a profile picture.
class ImageModerationService {
  static const String _backendBase = '${BackendConfig.baseUrl}/api';

  /// Returns a [ModerationResult]. If the moderation service can't be
  /// reached or isn't configured, [checked] is false and [safe] defaults to
  /// true so the app degrades gracefully rather than blocking every upload.
  static Future<ModerationResult> checkImage(Uint8List bytes) async {
    try {
      final uri = Uri.parse('$_backendBase/moderate-image');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'imageBase64': base64Encode(bytes)}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final reasons = (data['reasons'] as List?)?.cast<String>() ?? const [];
        return ModerationResult(safe: data['safe'] == true, reasons: reasons, checked: true);
      }
      debugPrint('Image moderation unavailable (${resp.statusCode}): ${resp.body}');
    } catch (e) {
      debugPrint('Image moderation check failed: $e');
    }
    return const ModerationResult(safe: true, checked: false);
  }
}
