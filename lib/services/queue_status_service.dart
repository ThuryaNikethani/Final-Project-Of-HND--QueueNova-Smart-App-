import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/backend_config.dart';

/// Citizen-side lookup for "where do I stand in the queue right now",
/// backed by the same Postgres `queue_entries` table the officer's Queue
/// Management dashboard reads/writes. Talks to the backend directly via
/// plain `http`, matching the convention already used by
/// `AppointmentService._mirrorToPostgres` (citizen-side code doesn't import
/// the web-dashboard's `WebApiService`).
class QueueStatusService {
  static const String _base = BackendConfig.baseUrl;

  /// Returns `{found, token, officeId, service, status, position}` or
  /// `{found: false}` if the citizen has no active (waiting/serving) queue
  /// entry right now.
  static Future<Map<String, dynamic>> getMyQueuePosition(String nic) async {
    if (nic.isEmpty) return {'found': false};
    try {
      final res = await http
          .get(Uri.parse('$_base/api/queue/position/${Uri.encodeComponent(nic)}'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('QueueStatusService.getMyQueuePosition error: $e');
    }
    return {'found': false};
  }

  /// Office-wide queue stats (waiting/serving counts, the token currently
  /// being served, average wait) from the same endpoint the officer's Queue
  /// Management dashboard uses. Returns `{}` on failure.
  static Future<Map<String, dynamic>> getOfficeStats(String officeId) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/api/web/queue/stats/${Uri.encodeComponent(officeId)}'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('QueueStatusService.getOfficeStats error: $e');
    }
    return {};
  }

  /// Full list of citizens currently waiting at [officeId], ordered the same
  /// way the officer dashboard's "Call Next" picks from it (oldest first).
  /// Returns `[]` on failure.
  static Future<List<Map<String, dynamic>>> getWaitingList(String officeId) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/api/web/queue/${Uri.encodeComponent(officeId)}'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List;
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('QueueStatusService.getWaitingList error: $e');
    }
    return [];
  }

  /// This citizen's average wait time (minutes) across all their completed
  /// queue entries, any office. Returns null if there's no history yet.
  static Future<double?> getCitizenAvgWaitMinutes(String nic) async {
    if (nic.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse('$_base/api/web/queue/stats/citizen/${Uri.encodeComponent(nic)}'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['avgWaitMinutes'] as num?)?.toDouble();
      }
    } catch (e) {
      debugPrint('QueueStatusService.getCitizenAvgWaitMinutes error: $e');
    }
    return null;
  }

  /// This citizen's average feedback rating (out of 5) across everything
  /// they've submitted via the Feedback screen. Returns null if they haven't
  /// left any feedback yet.
  static Future<double?> getCitizenAvgRating(String nic) async {
    if (nic.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse('$_base/api/web/feedback/citizen/${Uri.encodeComponent(nic)}'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['avgRating'] as num?)?.toDouble();
      }
    } catch (e) {
      debugPrint('QueueStatusService.getCitizenAvgRating error: $e');
    }
    return null;
  }

  /// Opens a Socket.IO connection to the backend so callers can react the
  /// moment an officer calls next / completes / cancels / adds a queue
  /// entry (the backend already emits these — `server.js` `io.emit('queue_update', ...)`
  /// / `io.emit('service_completed', ...)`). Callers own the returned socket
  /// and must call `.dispose()` on it when done (e.g. in `dispose()`).
  static io.Socket connect({
    required void Function() onQueueChanged,
  }) {
    final socket = io.io(
      _base,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    socket.onConnect((_) => debugPrint('QueueStatusService socket connected'));
    socket.on('queue_update', (_) => onQueueChanged());
    socket.on('service_completed', (_) => onQueueChanged());
    socket.connect();
    return socket;
  }
}
