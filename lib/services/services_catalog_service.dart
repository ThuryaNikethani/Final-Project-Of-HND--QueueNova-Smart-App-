import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';

/// Fetches the government services catalog (All Services / Book Appointment
/// screens) from the PostgreSQL-backed `/api/services` endpoint. Returns an
/// empty list on any failure so callers can fall back to their existing
/// static defaults, same pattern as the rest of the app's backend calls.
class ServicesCatalogService {
  static Future<List<Map<String, dynamic>>> getServices() async {
    try {
      final res = await http
          .get(Uri.parse('${BackendConfig.baseUrl}/api/services'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('ServicesCatalogService.getServices error: $e');
    }
    return [];
  }
}
