import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Outcome of a send (SMS/push) request, kept detailed enough to write an
/// audit log entry even on failure.
class SendResult {
  final bool success;
  final String? error;
  const SendResult(this.success, [this.error]);
}

/// HTTP client for the QueueNova Node.js/PostgreSQL backend.
/// Every method falls back silently on error so existing in-memory state
/// still works when the server is not running.
class WebApiService {
  static const String _base = 'http://localhost:3000/api/web';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Returns `{id, name, email, role}` or null on bad credentials / error.
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/auth/login'),
            headers: _headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      return null;
    } catch (e) {
      debugPrint('WebApiService.login error: $e');
      return null;
    }
  }

  // ── Dashboard ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/dashboard/stats'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getDashboardStats error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getDashboardActivity() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/dashboard/activity'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getDashboardActivity error: $e');
    }
    return [];
  }

  // ── Queue ───────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getQueue(String officeId) async {
    try {
      final encoded = Uri.encodeComponent(officeId);
      final res = await http
          .get(Uri.parse('$_base/queue/$encoded'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getQueue error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> callNext(String officeId, String officerName) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/queue/call-next'),
            headers: _headers,
            body: jsonEncode({'officeId': officeId, 'officerName': officerName}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.callNext error: $e');
    }
    return null;
  }

  static Future<bool> completeService(String token, String officerName) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/queue/complete'),
            headers: _headers,
            body: jsonEncode({'token': token, 'officerName': officerName}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.completeService error: $e');
    }
    return false;
  }

  static Future<bool> reassignCounter(String token, int counter, String officerName) async {
    try {
      final encoded = Uri.encodeComponent(token);
      final res = await http
          .put(
            Uri.parse('$_base/queue/$encoded/counter'),
            headers: _headers,
            body: jsonEncode({'counter': counter, 'officerName': officerName}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.reassignCounter error: $e');
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> getEmergencyQueue(String officeId) async {
    try {
      final encoded = Uri.encodeComponent(officeId);
      final res = await http
          .get(Uri.parse('$_base/queue/emergency/$encoded'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getEmergencyQueue error: $e');
    }
    return [];
  }

  static Future<bool> processEmergency(String token, String officerName) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/queue/emergency/process'),
            headers: _headers,
            body: jsonEncode({'token': token, 'officerName': officerName}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.processEmergency error: $e');
    }
    return false;
  }

  // ── Staff Users ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/users'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getUsers error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String createdBy = 'Admin',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/users'),
            headers: _headers,
            body: jsonEncode({'name': name, 'email': email, 'password': password, 'role': role, 'createdBy': createdBy}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.createUser error: $e');
    }
    return null;
  }

  static Future<bool> updateUser({
    required int id,
    required String name,
    required String email,
    required String role,
    String updatedBy = 'Admin',
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/users/$id'),
            headers: _headers,
            body: jsonEncode({'name': name, 'email': email, 'role': role, 'updatedBy': updatedBy}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.updateUser error: $e');
    }
    return false;
  }

  static Future<bool> deleteUser(int id, {String deletedBy = 'Admin'}) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_base/users/$id'),
            headers: _headers,
            body: jsonEncode({'deletedBy': deletedBy}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.deleteUser error: $e');
    }
    return false;
  }

  // ── Documents ───────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/documents'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getDocuments error: $e');
    }
    return [];
  }

  static Future<bool> approveDocument(int id, String reviewedBy) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/documents/$id/approve'),
            headers: _headers,
            body: jsonEncode({'reviewedBy': reviewedBy}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.approveDocument error: $e');
    }
    return false;
  }

  static Future<bool> rejectDocument(int id, String reviewedBy, {String reason = ''}) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/documents/$id/reject'),
            headers: _headers,
            body: jsonEncode({'reviewedBy': reviewedBy, 'reason': reason}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.rejectDocument error: $e');
    }
    return false;
  }

  // ── Appointments ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getAppointments() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/appointments'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getAppointments error: $e');
    }
    return [];
  }

  static Future<bool> updateAppointmentStatus(String id, {String? status, String? paymentStatus}) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/appointments/$id/status'),
            headers: _headers,
            body: jsonEncode({'status': status, 'payment_status': paymentStatus}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.updateAppointmentStatus error: $e');
    }
    return false;
  }

  // ── System ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getSystemHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/system/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getSystemHealth error: $e');
    }
    return null;
  }

  // ── Audit Logs ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 100}) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/audit-logs?limit=$limit'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getAuditLogs error: $e');
    }
    return [];
  }

  // ── Queue (extended) ────────────────────────────────────────────────────────

  /// Live queue statistics for an office (waiting count, avg wait, service type).
  static Future<Map<String, dynamic>?> getQueueStats(String officeId) async {
    try {
      final encoded = Uri.encodeComponent(officeId);
      final res = await http
          .get(Uri.parse('$_base/queue/stats/$encoded'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getQueueStats error: $e');
    }
    return null;
  }

  /// Add a walk-in queue entry. Returns the new entry with token number.
  static Future<Map<String, dynamic>?> addQueueEntry({
    required String officeId,
    required String citizenName,
    required String citizenNic,
    required String serviceType,
    String addedBy = 'Staff',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/queue'),
            headers: _headers,
            body: jsonEncode({
              'officeId': officeId,
              'citizenName': citizenName,
              'citizenNic': citizenNic,
              'serviceType': serviceType,
              'addedBy': addedBy,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.addQueueEntry error: $e');
    }
    return null;
  }

  /// Add an emergency queue entry (priority lane).
  static Future<Map<String, dynamic>?> addEmergencyQueueEntry({
    required String officeId,
    required String citizenName,
    required String citizenNic,
    required String reason,
    String addedBy = 'Staff',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/queue/emergency'),
            headers: _headers,
            body: jsonEncode({
              'officeId': officeId,
              'citizenName': citizenName,
              'citizenNic': citizenNic,
              'reason': reason,
              'addedBy': addedBy,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.addEmergencyQueueEntry error: $e');
    }
    return null;
  }

  /// Cancel (remove) a queue entry by token.
  static Future<bool> cancelQueueEntry(String token) async {
    try {
      final encoded = Uri.encodeComponent(token);
      final res = await http
          .delete(Uri.parse('$_base/queue/$encoded'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.cancelQueueEntry error: $e');
    }
    return false;
  }

  // ── Office Settings ──────────────────────────────────────────────────────────

  /// Fetch settings for a specific office, or all offices if [officeId] is null.
  static Future<Map<String, dynamic>?> getOfficeSettings([String? officeId]) async {
    try {
      final url = officeId != null
          ? '$_base/office-settings/${Uri.encodeComponent(officeId)}'
          : '$_base/office-settings';
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getOfficeSettings error: $e');
    }
    return null;
  }

  /// Create or update settings for a specific office.
  static Future<bool> updateOfficeSettings(
      String officeId, Map<String, dynamic> settings) async {
    try {
      final encoded = Uri.encodeComponent(officeId);
      final res = await http
          .put(
            Uri.parse('$_base/office-settings/$encoded'),
            headers: _headers,
            body: jsonEncode(settings),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.updateOfficeSettings error: $e');
    }
    return false;
  }

  // ── Analytics ────────────────────────────────────────────────────────────────

  /// Overview analytics (total queued, completed, avg wait, etc.).
  static Future<Map<String, dynamic>?> getAnalyticsOverview({String? officeId}) async {
    try {
      final q = officeId != null ? '?officeId=${Uri.encodeComponent(officeId)}' : '';
      final res = await http
          .get(Uri.parse('$_base/analytics/overview$q'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getAnalyticsOverview error: $e');
    }
    return null;
  }

  /// Daily queue volume trend for the last [days] days.
  static Future<List<Map<String, dynamic>>> getQueueTrends(
      {String? officeId, int days = 7}) async {
    try {
      var q = '?days=$days';
      if (officeId != null) q += '&officeId=${Uri.encodeComponent(officeId)}';
      final res = await http
          .get(Uri.parse('$_base/analytics/queue-trends$q'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getQueueTrends error: $e');
    }
    return [];
  }

  /// Service-type performance breakdown (avg duration, count, completion rate).
  static Future<List<Map<String, dynamic>>> getServicePerformance(
      {String? officeId}) async {
    try {
      final q = officeId != null ? '?officeId=${Uri.encodeComponent(officeId)}' : '';
      final res = await http
          .get(Uri.parse('$_base/analytics/service-performance$q'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getServicePerformance error: $e');
    }
    return [];
  }

  /// Per-staff service performance (tokens served, avg handling time).
  static Future<List<Map<String, dynamic>>> getStaffPerformance(
      {String? officeId}) async {
    try {
      final q = officeId != null ? '?officeId=${Uri.encodeComponent(officeId)}' : '';
      final res = await http
          .get(Uri.parse('$_base/analytics/staff-performance$q'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getStaffPerformance error: $e');
    }
    return [];
  }

  // ── Appointments (extended) ──────────────────────────────────────────────────

  /// Full-text appointment search by citizen name, NIC, or service type.
  static Future<List<Map<String, dynamic>>> searchAppointments(String query) async {
    try {
      final q = Uri.encodeComponent(query);
      final res = await http
          .get(Uri.parse('$_base/appointments/search?q=$q'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.searchAppointments error: $e');
    }
    return [];
  }

  // ── Users (extended) ─────────────────────────────────────────────────────────

  /// Change a staff member's password (verified against [oldPassword]).
  static Future<bool> changePassword(
      int id, String oldPassword, String newPassword) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/users/$id/password'),
            headers: _headers,
            body: jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.changePassword error: $e');
    }
    return false;
  }

  /// Activate or deactivate a staff account. [status] is `'active'` or `'inactive'`.
  static Future<bool> updateUserStatus(int id, String status) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/users/$id/status'),
            headers: _headers,
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.updateUserStatus error: $e');
    }
    return false;
  }

  // ── Notifications ─────────────────────────────────────────────────────────────

  /// Send a notification to a user or broadcast to all staff.
  static Future<bool> sendNotification({
    required int userId,
    required String title,
    required String message,
    String type = 'info',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/notifications'),
            headers: _headers,
            body: jsonEncode({
              'userId': userId,
              'title': title,
              'message': message,
              'type': type,
            }),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.sendNotification error: $e');
    }
    return false;
  }

  /// Delete a notification by ID.
  static Future<bool> deleteNotification(int id) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/notifications/$id'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.deleteNotification error: $e');
    }
    return false;
  }

  // ── SMS ─────────────────────────────────────────────────────────────────────

  static const String _smsBase = 'http://localhost:3000/api/sms';

  /// Send an SMS via Twilio (server-side, delivered regardless of whether the
  /// citizen's app is open). [phone] must be in E.164 format (e.g. `+94771234567`).
  static Future<SendResult> sendSms(String phone, String message) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_smsBase/send'),
            headers: _headers,
            body: jsonEncode({'phone': phone, 'message': message}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return const SendResult(true);
      final error = _extractError(res.body) ?? 'HTTP ${res.statusCode}';
      debugPrint('WebApiService.sendSms failed: $error');
      return SendResult(false, error);
    } catch (e) {
      debugPrint('WebApiService.sendSms error: $e');
      return SendResult(false, e.toString());
    }
  }

  static String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded['error'] as String?;
    } catch (_) {}
    return null;
  }

  // ── Push Notifications (FCM) ─────────────────────────────────────────────────

  static const String _pushBase = 'http://localhost:3000/api/push';

  /// Send a push notification to one or more FCM device tokens, delivered
  /// regardless of whether the app is open (foreground, backgrounded, or
  /// closed on mobile; open in another tab or closed on web).
  static Future<SendResult> sendPush(List<String> tokens, String title, String body) async {
    if (tokens.isEmpty) return const SendResult(false, 'no device tokens');
    try {
      final res = await http
          .post(
            Uri.parse('$_pushBase/send'),
            headers: _headers,
            body: jsonEncode({'tokens': tokens, 'title': title, 'body': body}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return const SendResult(true);
      final error = _extractError(res.body) ?? 'HTTP ${res.statusCode}';
      debugPrint('WebApiService.sendPush failed: $error');
      return SendResult(false, error);
    } catch (e) {
      debugPrint('WebApiService.sendPush error: $e');
      return SendResult(false, e.toString());
    }
  }

  // ── ML Predictions ────────────────────────────────────────────────────────────

  static const _mlBase = 'http://localhost:3000/api/ml';

  static Future<Map<String, dynamic>?> _mlPost(
      String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_mlBase/$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['fallback'] == true) return null;
        return data;
      }
    } catch (e) {
      debugPrint('WebApiService.mlPost($path) error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _mlGet(String path) async {
    try {
      final res = await http
          .get(Uri.parse('$_mlBase/$path'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.mlGet($path) error: $e');
    }
    return null;
  }

  /// Check if the ML server is running and models are loaded.
  static Future<Map<String, dynamic>?> mlHealth() => _mlGet('health');

  /// Predict wait time, crowd level, peak probability, and best visit time.
  ///
  /// Required keys: `officeType`, `district`, `serviceType`, `hour`, `dayOfWeek`,
  /// `month`, `numCounters`, `serviceAvgMin`.
  /// Optional: `queueAtArrival`, `isHoliday`.
  static Future<Map<String, dynamic>?> mlPredictWaitTime(
          Map<String, dynamic> params) =>
      _mlPost('predict/wait-time', params);

  /// Hourly wait-time and crowd forecast from 8 AM to 4 PM.
  ///
  /// Required keys: `officeType`, `district`, `serviceType`, `dayOfWeek`,
  /// `month`, `numCounters`, `serviceAvgMin`.
  static Future<Map<String, dynamic>?> mlPredictPeakHours(
          Map<String, dynamic> params) =>
      _mlPost('predict/peak-hours', params);

  /// Forecast total daily visitor demand for a service at an office.
  ///
  /// Required keys: `officeType`, `district`, `serviceType`, `month`, `dayOfWeek`,
  /// `serviceAvgMin`.
  static Future<Map<String, dynamic>?> mlPredictDemand(
          Map<String, dynamic> params) =>
      _mlPost('predict/demand', params);

  /// Crowd level classification with full probability distribution.
  ///
  /// Required keys: `officeType`, `district`, `serviceType`, `hour`, `dayOfWeek`,
  /// `month`, `numCounters`, `serviceAvgMin`.
  static Future<Map<String, dynamic>?> mlPredictCrowd(
          Map<String, dynamic> params) =>
      _mlPost('predict/crowd', params);

  /// Rank a list of offices by predicted experience score.
  ///
  /// Required keys: `offices` (list with `name`, `type`, `district`, `counters`),
  /// `serviceType`, `serviceAvgMin`, `hour`, `dayOfWeek`, `month`.
  static Future<Map<String, dynamic>?> mlRecommendOffice(
          Map<String, dynamic> params) =>
      _mlPost('recommend/office', params);

  /// Predict appointment no-show probability.
  ///
  /// Required keys: `serviceType`, `district`, `hour`, `dayOfWeek`, `month`,
  /// `fee`, `isPrepaid`, `daysInAdvance`, `serviceAvgMin`.
  static Future<Map<String, dynamic>?> mlPredictNoShow(
          Map<String, dynamic> params) =>
      _mlPost('predict/no-show', params);

  /// Predict queue abandonment risk for a waiting citizen.
  ///
  /// Required keys: `currentQueueLength`, `estimatedWaitMin`, `serviceType`,
  /// `serviceAvgMin`, `hour`, `dayOfWeek`, `fee`, `isPriority`, `district`.
  static Future<Map<String, dynamic>?> mlPredictAbandonment(
          Map<String, dynamic> params) =>
      _mlPost('predict/abandonment', params);

  /// Predict actual service handling duration with confidence interval.
  ///
  /// Required keys: `serviceType`, `officeType`, `hour`, `dayOfWeek`, `month`,
  /// `queueAtArrival`, `district`, `serviceAvgMin`.
  static Future<Map<String, dynamic>?> mlPredictServiceDuration(
          Map<String, dynamic> params) =>
      _mlPost('predict/service-duration', params);

  /// Recommend the optimal number of open counters for current demand.
  ///
  /// Required keys: `officeType`, `district`, `serviceType`, `serviceAvgMin`,
  /// `hour`, `dayOfWeek`, `month`, `arrivalsPerHour`, `availableStaff`.
  static Future<Map<String, dynamic>?> mlRecommendCounters(
          Map<String, dynamic> params) =>
      _mlPost('recommend/counters', params);

  /// Predict citizen satisfaction score (1–5) after a visit.
  ///
  /// Required keys: `actualWaitMin`, `predictedWaitMin`, `serviceType`,
  /// `serviceAvgMin`, `crowdLevelCode`, `hour`, `dayOfWeek`,
  /// `isServiceCompleted`, `officeType`, `district`.
  static Future<Map<String, dynamic>?> mlPredictSatisfaction(
          Map<String, dynamic> params) =>
      _mlPost('predict/satisfaction', params);
}
