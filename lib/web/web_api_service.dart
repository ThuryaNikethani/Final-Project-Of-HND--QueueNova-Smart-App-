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
  /// Backend origin (scheme+host+port), overridable at build time with
  /// `--dart-define=API_ORIGIN=https://your-backend.example.com` for
  /// deployments where the dashboard isn't served from the same host as
  /// the Node/Postgres server. Defaults to the local dev server unchanged.
  static const String apiOrigin =
      String.fromEnvironment('API_ORIGIN', defaultValue: 'http://localhost:3000');

  static const String _base = '$apiOrigin/api/web';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Returns `{id, name, email, role}` on success, or null when the server
  /// was reached but rejected the credentials. Network/timeout failures are
  /// thrown rather than swallowed, so the caller can tell "server said no"
  /// (must not fall back to any offline demo credentials) apart from
  /// "server unreachable" (fallback is appropriate).
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$_base/auth/login'),
          headers: _headers,
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    return null;
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

  /// Tokens already called (Call Next) but not yet marked Complete.
  static Future<List<Map<String, dynamic>>> getServingQueue(String officeId) async {
    try {
      final encoded = Uri.encodeComponent(officeId);
      final res = await http
          .get(Uri.parse('$_base/queue/$encoded/serving'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getServingQueue error: $e');
    }
    return [];
  }

  /// Returns null on success, or the server's rejection message (e.g. Max
  /// Queue per Counter / Priority Queue Limit reached) on failure — the
  /// caller should surface that message rather than treat this as a bare
  /// pass/fail, since these limits come from Queue Settings and the officer
  /// needs to know *why* it didn't go through.
  static Future<String?> addToQueue({
    required String token,
    required String officeId,
    required String citizenName,
    String? citizenNic,
    required String service,
    int counter = 1,
    bool isPriority = false,
    String paymentStatus = 'pending',
    double fee = 0,
    String? waitTime,
    required String officerName,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/queue'),
            headers: _headers,
            body: jsonEncode({
              'token': token,
              'officeId': officeId,
              'citizenName': citizenName,
              'citizenNic': citizenNic,
              'service': service,
              'counter': counter,
              'isPriority': isPriority,
              'paymentStatus': paymentStatus,
              'fee': fee,
              'waitTime': waitTime,
              'officerName': officerName,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return null;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['error'] as String? ?? 'Failed to add to queue';
      } catch (_) {
        return 'Failed to add to queue';
      }
    } catch (e) {
      debugPrint('WebApiService.addToQueue error: $e');
      return 'Failed to add to queue: $e';
    }
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
    String? phone,
    String updatedBy = 'Admin',
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/users/$id'),
            headers: _headers,
            body: jsonEncode({'name': name, 'email': email, 'role': role, 'phone': phone, 'updatedBy': updatedBy}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.updateUser error: $e');
    }
    return false;
  }

  static Future<bool> updatePhoto(int id, String? photoBase64, {String updatedBy = 'Admin'}) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/users/$id/photo'),
            headers: _headers,
            body: jsonEncode({'photoBase64': photoBase64, 'updatedBy': updatedBy}),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.updatePhoto error: $e');
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

  /// Cross-department sharing — sets the full list of departments a
  /// document is shared with.
  static Future<bool> shareDocument(int id, List<String> departments, {String sharedBy = 'Officer'}) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/documents/$id/share'),
            headers: _headers,
            body: jsonEncode({'departments': departments, 'sharedBy': sharedBy}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.shareDocument error: $e');
    }
    return false;
  }

  // ── Service Requests (Service Processing screen) ────────────────────────────

  /// Appointments with their attached documents grouped into one application.
  static Future<List<Map<String, dynamic>>> getServiceRequests() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/service-requests'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getServiceRequests error: $e');
    }
    return [];
  }

  /// Approves every document attached to appointment [appointmentId].
  static Future<bool> approveServiceRequest(String appointmentId, String reviewedBy) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/service-requests/$appointmentId/approve'),
            headers: _headers,
            body: jsonEncode({'reviewedBy': reviewedBy}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.approveServiceRequest error: $e');
    }
    return false;
  }

  /// Rejects every document attached to appointment [appointmentId] with [reason].
  static Future<bool> rejectServiceRequest(String appointmentId, String reviewedBy, {String reason = ''}) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/service-requests/$appointmentId/reject'),
            headers: _headers,
            body: jsonEncode({'reviewedBy': reviewedBy, 'reason': reason}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.rejectServiceRequest error: $e');
    }
    return false;
  }

  /// Shares every document attached to appointment [appointmentId] with [departments]
  /// (additive — keeps whatever they were already shared with).
  static Future<bool> shareServiceRequest(String appointmentId, List<String> departments, {String sharedBy = 'Officer'}) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/service-requests/$appointmentId/share'),
            headers: _headers,
            body: jsonEncode({'departments': departments, 'sharedBy': sharedBy}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.shareServiceRequest error: $e');
    }
    return false;
  }

  /// Approves or rejects a citizen's self-requested priority-queue upgrade
  /// (flips `is_priority` on their still-waiting queue entry, or leaves it
  /// alone on reject). [token] is the citizen's queue token, e.g. "A-025".
  /// Returns null on success, or the server's rejection message (e.g.
  /// Priority Queue disabled, or Priority Queue Limit reached) on failure —
  /// same convention as [addToQueue], for the same reason: the officer
  /// needs to know *why* an approval didn't go through.
  static Future<String?> setQueuePriority(String token, bool approve, {String officerName = 'Officer'}) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/queue/$token/priority'),
            headers: _headers,
            body: jsonEncode({'approve': approve, 'officerName': officerName}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return null;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['error'] as String? ?? 'Failed to update priority';
      } catch (_) {
        return 'Failed to update priority';
      }
    } catch (e) {
      debugPrint('WebApiService.setQueuePriority error: $e');
      return 'Failed to update priority: $e';
    }
  }

  // ── Reports ──────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getReports() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/reports'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getReports error: $e');
    }
    return [];
  }

  /// Generates a PDF report on the server from real appointment/queue data
  /// and returns its metadata (including `id`, used to build the download
  /// URL), or null on failure.
  static Future<Map<String, dynamic>?> generateReport({
    required String reportType,
    required DateTime date,
    String generatedBy = 'Admin',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/reports/generate'),
            headers: _headers,
            body: jsonEncode({
              'reportType': reportType,
              'date': date.toIso8601String().substring(0, 10),
              'generatedBy': generatedBy,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['report'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('WebApiService.generateReport error: $e');
    }
    return null;
  }

  /// Direct-download URL for a generated report PDF (opens/saves via the
  /// browser, same pattern as document downloads).
  static String reportDownloadUrl(int id) => '$_base/reports/download/$id';

  // ── Backup & Restore ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getBackups() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/backup'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getBackups error: $e');
    }
    return [];
  }

  /// Dumps every table in the database to a new backup file. Can take a
  /// few seconds on a large database.
  static Future<Map<String, dynamic>?> createBackup({String createdBy = 'Admin'}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/backup/create'),
            headers: _headers,
            body: jsonEncode({'createdBy': createdBy}),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['backup'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('WebApiService.createBackup error: $e');
    }
    return null;
  }

  static String backupDownloadUrl(int id) => '$_base/backup/download/$id';

  static Future<bool> deleteBackup(int id, {String deletedBy = 'Admin'}) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_base/backup/$id'),
            headers: _headers,
            body: jsonEncode({'deletedBy': deletedBy}),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.deleteBackup error: $e');
    }
    return false;
  }

  /// Destructive: truncates and reloads every table the backup captured.
  /// The server always takes a fresh safety backup of the current state
  /// first, so this can itself be undone by restoring that safety backup.
  static Future<Map<String, dynamic>?> restoreBackup(int id, {String restoredBy = 'Admin'}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/backup/$id/restore'),
            headers: _headers,
            body: jsonEncode({'restoredBy': restoredBy}),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('WebApiService.restoreBackup failed: ${res.body}');
    } catch (e) {
      debugPrint('WebApiService.restoreBackup error: $e');
    }
    return null;
  }

  // ── System Settings ──────────────────────────────────────────────────────────

  /// Returns the singleton settings blob, e.g. `{id, settings: {...}, updated_at}`.
  static Future<Map<String, dynamic>?> getSystemSettings() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/system-settings'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getSystemSettings error: $e');
    }
    return null;
  }

  static Future<bool> saveSystemSettings(Map<String, dynamic> settings, {String updatedBy = 'Admin'}) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/system-settings'),
            headers: _headers,
            body: jsonEncode({'settings': settings, 'updatedBy': updatedBy}),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.saveSystemSettings error: $e');
    }
    return false;
  }

  // ── Security Settings ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getSecuritySettings() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/security-settings'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getSecuritySettings error: $e');
    }
    return null;
  }

  static Future<bool> saveSecuritySettings(Map<String, dynamic> settings, {String updatedBy = 'Admin'}) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/security-settings'),
            headers: _headers,
            body: jsonEncode({'settings': settings, 'updatedBy': updatedBy}),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.saveSecuritySettings error: $e');
    }
    return false;
  }

  // ── Departments ───────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDepartments() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/departments'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getDepartments error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> addDepartment({
    required String name,
    required String code,
    required String type,
    String createdBy = 'Admin',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/departments'),
            headers: _headers,
            body: jsonEncode({'name': name, 'code': code, 'type': type, 'createdBy': createdBy}),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['department'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('WebApiService.addDepartment error: $e');
    }
    return null;
  }

  static Future<bool> setDepartmentActive(int id, bool active) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/departments/$id/status'),
            headers: _headers,
            body: jsonEncode({'active': active}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.setDepartmentActive error: $e');
    }
    return false;
  }

  static Future<bool> deleteDepartment(int id, {String deletedBy = 'Admin'}) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_base/departments/$id'),
            headers: _headers,
            body: jsonEncode({'deletedBy': deletedBy}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.deleteDepartment error: $e');
    }
    return false;
  }

  // ── Online Service Requests ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getOnlineRequests() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/online-requests'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getOnlineRequests error: $e');
    }
    return [];
  }

  /// Accepts the request and forwards it to [targetDepartment] in one action.
  static Future<bool> acceptOnlineRequest(String id, {required String staffId, required String staffName, required String targetDepartment}) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/online-requests/$id/accept'),
            headers: _headers,
            body: jsonEncode({'staffId': staffId, 'staffName': staffName, 'targetDepartment': targetDepartment}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.acceptOnlineRequest error: $e');
    }
    return false;
  }

  static Future<bool> rejectOnlineRequest(String id, {required String staffId, required String staffName, required String reason}) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/online-requests/$id/reject'),
            headers: _headers,
            body: jsonEncode({'staffId': staffId, 'staffName': staffName, 'reason': reason}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.rejectOnlineRequest error: $e');
    }
    return false;
  }

  /// The relevant office uploads the finished result (e.g. the certificate).
  static Future<bool> completeOnlineRequestAtOffice(
    String id, {
    required String staffId,
    required String staffName,
    required String citizenName,
    required String citizenNic,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/online-requests/$id/office-complete'),
      )
        ..fields['staffId'] = staffId
        ..fields['staffName'] = staffName
        ..fields['citizenName'] = citizenName
        ..fields['citizenNic'] = citizenNic
        ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
      final streamed = await request.send().timeout(const Duration(seconds: 15));
      return streamed.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.completeOnlineRequestAtOffice error: $e');
    }
    return false;
  }

  /// The Service Officer's final "Share with Citizen" action.
  static Future<bool> deliverOnlineRequest(String id, {required String staffId, required String staffName}) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/online-requests/$id/deliver'),
            headers: _headers,
            body: jsonEncode({'staffId': staffId, 'staffName': staffName}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.deliverOnlineRequest error: $e');
    }
    return false;
  }

  static Future<bool> setServiceOnlineEligible(int serviceId, bool onlineEligible) async {
    try {
      final res = await http
          .put(
            Uri.parse('$apiOrigin/api/services/$serviceId/online-eligible'),
            headers: _headers,
            body: jsonEncode({'onlineEligible': onlineEligible}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.setServiceOnlineEligible error: $e');
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> getServicesCatalog() async {
    try {
      final res = await http
          .get(Uri.parse('$apiOrigin/api/services'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getServicesCatalog error: $e');
    }
    return [];
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

  static Future<bool> updateAppointmentStatus(String id, {String? status, String? paymentStatus, String updatedBy = 'Officer'}) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/appointments/$id/status'),
            headers: _headers,
            body: jsonEncode({'status': status, 'payment_status': paymentStatus, 'updatedBy': updatedBy}),
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

  /// Stats specifically for the Reception dashboard's own stat cards
  /// (active queue, arrivals today, walk-ins today) for one office.
  static Future<Map<String, dynamic>?> getReceptionStats(String officeId) async {
    try {
      final encoded = Uri.encodeComponent(officeId);
      final res = await http
          .get(Uri.parse('$_base/reception/stats/$encoded'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getReceptionStats error: $e');
    }
    return null;
  }

  /// Marks one specific queue token as being served now (used by
  /// Reception's Walk-in "Call Next", which must call a specific walk-in
  /// rather than whatever [callNext] would auto-pick for the whole office).
  static Future<bool> serveToken(String token, String officerName) async {
    try {
      final encoded = Uri.encodeComponent(token);
      final res = await http
          .post(
            Uri.parse('$_base/queue/$encoded/serve'),
            headers: _headers,
            body: jsonEncode({'officerName': officerName}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.serveToken error: $e');
    }
    return false;
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
      {String? officeId, int days = 7}) async {
    try {
      var q = '?days=$days';
      if (officeId != null) q += '&officeId=${Uri.encodeComponent(officeId)}';
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

  /// Real payment/transaction data from paid appointments: raw transaction
  /// list plus breakdowns by payment method and by service.
  static Future<Map<String, dynamic>> getPaymentReports({int days = 30}) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/payment-reports?days=$days'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getPaymentReports error: $e');
    }
    return {'transactions': [], 'byMethod': [], 'byService': []};
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
  static Future<SendResult> changePassword(
      int id, String oldPassword, String newPassword) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/users/$id/password'),
            headers: _headers,
            body: jsonEncode({'currentPassword': oldPassword, 'newPassword': newPassword}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return const SendResult(true);
      final error = _extractError(res.body) ?? 'HTTP ${res.statusCode}';
      return SendResult(false, error);
    } catch (e) {
      debugPrint('WebApiService.changePassword error: $e');
      return SendResult(false, e.toString());
    }
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

  // ── Feedback ────────────────────────────────────────────────────────────────

  /// Full list of citizen feedback (Dashboard's "Avg. Satisfaction" stat
  /// card, tapped open to review individual ratings/comments and reply).
  static Future<List<Map<String, dynamic>>> getFeedbackList() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/feedback'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('WebApiService.getFeedbackList error: $e');
    }
    return [];
  }

  static Future<bool> replyToFeedback(int id, String reply, String repliedBy) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/feedback/$id/reply'),
            headers: _headers,
            body: jsonEncode({'reply': reply, 'repliedBy': repliedBy}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.replyToFeedback error: $e');
    }
    return false;
  }

  /// Per-officer dashboard/app preferences (web_settings_screen.dart).
  /// Returns `{}` if nothing's been saved yet.
  static Future<Map<String, dynamic>> getUserPreferences(int id) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/users/$id/preferences'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WebApiService.getUserPreferences error: $e');
    }
    return {};
  }

  static Future<bool> updateUserPreferences(int id, Map<String, dynamic> settings) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/users/$id/preferences'),
            headers: _headers,
            body: jsonEncode({'settings': settings}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('WebApiService.updateUserPreferences error: $e');
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

  static const String _smsBase = '$apiOrigin/api/sms';

  /// Send an SMS via Twilio (server-side, delivered regardless of whether the
  /// citizen's app is open). [phone] must be in E.164 format (e.g. `+94771234567`).
  /// Reads the `smsNotifications`/`pushNotifications` toggles saved from the
  /// System Settings screen. Missing settings (nothing saved yet) default to
  /// enabled, matching the screen's own default toggle state.
  static Future<bool> _isNotificationChannelEnabled(String key) async {
    final res = await getSystemSettings();
    final settings = res?['settings'] as Map<String, dynamic>?;
    if (settings == null) return true;
    return settings[key] as bool? ?? true;
  }

  static Future<SendResult> sendSms(String phone, String message) async {
    if (!await _isNotificationChannelEnabled('smsNotifications')) {
      return const SendResult(false, 'SMS notifications are disabled in System Settings');
    }
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

  static const String _pushBase = '$apiOrigin/api/push';

  /// Send a push notification to one or more FCM device tokens, delivered
  /// regardless of whether the app is open (foreground, backgrounded, or
  /// closed on mobile; open in another tab or closed on web).
  static Future<SendResult> sendPush(List<String> tokens, String title, String body) async {
    if (tokens.isEmpty) return const SendResult(false, 'no device tokens');
    if (!await _isNotificationChannelEnabled('pushNotifications')) {
      return const SendResult(false, 'Push notifications are disabled in System Settings');
    }
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

  static const _mlBase = '$apiOrigin/api/ml';

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
