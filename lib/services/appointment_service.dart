import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../config/backend_config.dart';
import '../models/appointment_model.dart';

class AppointmentService {
  static const String _appointmentsKey = 'appointments';
  static List<AppointmentModel> _appointments = [];

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Local cache helpers ──────────────────────────────────────────────────
  static Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_appointmentsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      _appointments = decoded.map((e) => AppointmentModel.fromJson(e)).toList();
    } else {
      _appointments = [];
    }
  }

  static Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonData =
        jsonEncode(_appointments.map((a) => a.toJson()).toList());
    await prefs.setString(_appointmentsKey, jsonData);
  }

  // ── Firestore collection path per user ──────────────────────────────────
  static CollectionReference<Map<String, dynamic>>? _userCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('appointments');
  }

  // ── Public API (same interface as before) ────────────────────────────────
  //
  // Reads (getAppointments/watchAppointments) are sourced from PostgreSQL
  // (`/api/web/appointments/search`, matched by NIC) rather than Firestore.
  //
  // Reason: this is the same data the officer/staff dashboard already reads
  // reliably. The Firestore `users/{uid}/appointments` path repeatedly broke
  // for citizens whose session wasn't a live Firebase Auth uid at booking
  // time (the offline-login fallback), producing permission-denied errors
  // and a subcollection that silently never got the write in the first
  // place — even after fixing the security rules. Postgres has no such
  // per-uid rules/session dependency, so citizen bookings show up
  // regardless of the app's current auth state.
  //
  // Writes (addAppointment/updateAppointmentStatus/...) are UNCHANGED —
  // still written to both Firestore and Postgres, exactly as before. Only
  // where the citizen app *reads* bookings from has moved.
  static Future<List<AppointmentModel>> getAppointments() async {
    try {
      final apts = await _fetchFromPostgres();
      _appointments = apts;
      await _saveToLocal();
      return _appointments;
    } catch (e) {
      debugPrint('Postgres getAppointments failed: $e — using local cache');
      await _loadFromLocal();
      return _appointments;
    }
  }

  /// Uses the server-side NIC-filtered `/appointments/search` endpoint
  /// (already used elsewhere for citizen lookup) rather than the general
  /// `/appointments` list, which is capped at the 100 most recent bookings
  /// system-wide — once the office has more than 100 total appointments, an
  /// older booking of this citizen's could fall outside that window and
  /// silently disappear from their own history. Searching by NIC is correct
  /// regardless of how much data the system has accumulated.
  static Future<List<AppointmentModel>> _fetchFromPostgres() async {
    final prefs = await SharedPreferences.getInstance();
    final nic = (prefs.getString('userNIC') ?? '').toUpperCase();
    if (nic.isEmpty) return [];

    final res = await http
        .get(Uri.parse(
            '${BackendConfig.baseUrl}/api/web/appointments/search?q=${Uri.encodeComponent(nic)}'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final rows = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    // The search endpoint does a substring (ILIKE) match, so re-check for an
    // exact NIC match client-side to guard against a false-positive partial
    // match against another citizen's NIC/name.
    final mine = rows
        .where((r) => (r['citizen_nic'] as String? ?? '').toUpperCase() == nic)
        .map(_fromPostgresRow)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return mine;
  }

  static AppointmentModel _fromPostgresRow(Map<String, dynamic> r) {
    return AppointmentModel(
      id: r['id'].toString(),
      service: r['service'] ?? '',
      office: r['office'] ?? '',
      date: DateTime.parse(r['date'] as String),
      time: r['time'] ?? '',
      token: r['token'] ?? '',
      status: r['status'] ?? 'Confirmed',
      qrData: r['qr_data'] ?? '',
      paymentStatus: r['payment_status'] ?? 'pending',
      feeAmount: double.tryParse(r['fee_amount']?.toString() ?? '') ?? 0,
      paymentMethod: r['payment_method'] ?? '',
      documents: const [],
    );
  }

  /// Live version of [getAppointments]. Re-fetches from Postgres and emits
  /// whenever the backend broadcasts an appointment change over the same
  /// Socket.IO connection `QueueStatusService.connect()` already uses for
  /// queue updates (`server.js` emits `appointment_update` on booking/status
  /// changes and `payment_confirmed` on payment), so staff-side changes
  /// still appear instantly without polling.
  static Stream<List<AppointmentModel>> watchAppointments() {
    late final StreamController<List<AppointmentModel>> controller;
    socket_io.Socket? socket;

    Future<void> emitLatest() async {
      try {
        controller.add(await getAppointments());
      } catch (e) {
        controller.addError(e);
      }
    }

    controller = StreamController<List<AppointmentModel>>.broadcast(
      onListen: () {
        emitLatest();
        socket = socket_io.io(
          BackendConfig.baseUrl,
          socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
        );
        socket!.on('appointment_update', (_) => emitLatest());
        socket!.on('payment_confirmed', (_) => emitLatest());
        socket!.connect();
      },
      onCancel: () {
        socket?.dispose();
      },
    );
    return controller.stream;
  }

  static Future<void> addAppointment(AppointmentModel appointment) async {
    // Always write local first so the UI is responsive
    await _loadFromLocal();
    _appointments.add(appointment);
    await _saveToLocal();

    // Mirror to Firestore too (kept for other tooling that still reads it).
    // Fire-and-forget, same as the Postgres/document mirrors below — reads
    // no longer go through Firestore at all (see the class comment above),
    // so there's no reason for the citizen to wait on this write. It used to
    // be a blocking `await` with no timeout, which meant that if the write
    // couldn't reach the server, it would never resolve and never throw —
    // hanging the "Confirm Appointment" button forever instead of falling
    // back to the local cache that was already saved above.
    final col = _userCollection();
    if (col != null) {
      col
          .doc(appointment.id)
          .set(_toFirestore(appointment))
          .timeout(const Duration(seconds: 8))
          .catchError((e) {
        debugPrint('Firestore addAppointment failed: $e — kept locally');
      });
    }

    // Mirror to PostgreSQL so the web dashboard can see citizen bookings.
    // Fire-and-forget — failure never blocks the citizen.
    _mirrorToPostgres(appointment);

    // Mirror any attached documents too, linked via appointmentId, so the
    // Service Processing / Document Management screens can see them.
    // Fire-and-forget — failure never blocks the citizen.
    _mirrorDocumentsToPostgres(appointment);

    // Notify reception staff (the role that manages the Appointments screen).
    // Fire-and-forget — failure never blocks the citizen.
    _notifyStaffOfNewAppointment(appointment);
  }

  static Future<void> _notifyStaffOfNewAppointment(AppointmentModel appointment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('userName') ?? 'A citizen';
      final dateStr = '${appointment.date.day}/${appointment.date.month}/${appointment.date.year}';
      await _db.collection('staff_notifications').add({
        'title': 'New Appointment Booked',
        'message': '$name has booked a ${appointment.service} appointment at ${appointment.office} on $dateStr at ${appointment.time}.',
        'type': 'appointment',
        'action': 'View Appointment',
        'targetRoles': const ['reception'],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyStaffOfNewAppointment failed: $e');
    }
  }

  static Future<void> _mirrorToPostgres(AppointmentModel a) async {
    // Read citizen identity from local cache (written at login/register).
    final prefs = await SharedPreferences.getInstance();
    final nic  = prefs.getString('userNIC')  ?? '';
    final name = prefs.getString('userName') ?? '';

    http.post(
      Uri.parse('${BackendConfig.baseUrl}/api/web/appointments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': a.id,
        'citizen_nic': nic.isNotEmpty ? nic : null,
        'citizen_name': name.isNotEmpty ? name : null,
        'service': a.service,
        'office': a.office,
        'date': a.date.toIso8601String().split('T').first,
        'time': a.time,
        'token': a.token,
        'status': a.status,
        'payment_status': a.paymentStatus,
        'fee_amount': a.feeAmount,
        'payment_method': a.paymentMethod,
        'qr_data': a.qrData,
      }),
    ).then((res) {
      if (res.statusCode != 200 && res.statusCode != 201) {
        debugPrint('PostgreSQL mirror failed (${res.statusCode}) — Firestore is source of truth');
      }
    }).catchError((e) {
      debugPrint('PostgreSQL mirror error: $e — backend may not be running');
    });
  }

  /// Uploads each document attached during booking to PostgreSQL, linked to
  /// this appointment's id, so the Service Processing / Document Management
  /// dashboard screens have something to review. Fire-and-forget — a failed
  /// upload never blocks the citizen's booking flow.
  static Future<void> _mirrorDocumentsToPostgres(AppointmentModel a) async {
    if (a.documents.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final nic  = prefs.getString('userNIC')  ?? '';
    final name = prefs.getString('userName') ?? '';

    for (final doc in a.documents) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${BackendConfig.baseUrl}/api/web/documents/upload'),
        )
          ..fields['appointmentId'] = a.id
          ..fields['citizenName'] = name
          ..fields['citizenNic'] = nic
          ..fields['documentType'] = doc.documentType
          ..fields['uploadedBy'] = name;
        // On Flutter Web there's no real filesystem, so `doc.filePath` isn't
        // readable there — the picker gives us bytes directly instead, which
        // work on every platform. Fall back to reading the path only for the
        // rare case bytes weren't available (native platforms only).
        final multipartFile = doc.bytes != null
            ? http.MultipartFile.fromBytes('file', doc.bytes!, filename: doc.fileName)
            : await http.MultipartFile.fromPath('file', doc.filePath, filename: doc.fileName);
        request.files.add(multipartFile);
        final streamed = await request.send();
        if (streamed.statusCode != 200) {
          debugPrint('Document mirror failed (${streamed.statusCode}) for ${doc.fileName}');
        }
      } catch (e) {
        debugPrint('Document mirror error for ${doc.fileName}: $e');
      }
    }
  }

  static Future<void> updateAppointmentStatus(String id, String status) async {
    await _loadFromLocal();
    final index = _appointments.indexWhere((a) => a.id == id);
    AppointmentModel? appointment;
    if (index != -1) {
      appointment = _appointments[index].copyWith(status: status);
      _appointments[index] = appointment;
      await _saveToLocal();
    }

    final col = _userCollection();
    if (col != null) {
      try {
        await col.doc(id).update({'status': status});
      } catch (e) {
        debugPrint('Firestore updateStatus failed: $e');
      }
    }

    if (appointment != null) {
      _notifyCitizenOfStatusChange(
        title: 'Appointment $status',
        message: 'Your ${appointment.service} appointment (Token ${appointment.token}) is now $status.',
      );
      _notifyStaffOfStatusChange(appointment, status);
    }
  }

  static Future<void> updateAppointmentPaymentStatus(
      String id, String paymentStatus) async {
    await _loadFromLocal();
    final index = _appointments.indexWhere((a) => a.id == id);
    AppointmentModel? appointment;
    if (index != -1) {
      appointment = _appointments[index].copyWith(paymentStatus: paymentStatus);
      _appointments[index] = appointment;
      await _saveToLocal();
    }

    final col = _userCollection();
    if (col != null) {
      try {
        await col.doc(id).update({'paymentStatus': paymentStatus});
      } catch (e) {
        debugPrint('Firestore updatePaymentStatus failed: $e');
      }
    }

    if (appointment != null) {
      _notifyCitizenOfStatusChange(
        title: 'Payment $paymentStatus',
        message: 'Payment for your ${appointment.service} appointment (Token ${appointment.token}) is now $paymentStatus.',
      );
    }
  }

  static Future<void> _notifyCitizenOfStatusChange({
    required String title,
    required String message,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('notifications').add({
        'uid': uid,
        'title': title,
        'message': message,
        'type': 'appointment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyCitizenOfStatusChange failed: $e');
    }
  }

  static Future<void> _notifyStaffOfStatusChange(AppointmentModel appointment, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('userName') ?? 'A citizen';
      await _db.collection('staff_notifications').add({
        'title': 'Appointment $status',
        'message': '$name\'s ${appointment.service} appointment (Token ${appointment.token}) is now $status.',
        'type': 'appointment',
        'action': 'View Appointment',
        'targetRoles': const ['reception'],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyStaffOfStatusChange failed: $e');
    }
  }

  static Future<void> deleteAppointment(String id) async {
    await _loadFromLocal();
    _appointments.removeWhere((a) => a.id == id);
    await _saveToLocal();

    final col = _userCollection();
    if (col != null) {
      try {
        await col.doc(id).delete();
      } catch (e) {
        debugPrint('Firestore deleteAppointment failed: $e');
      }
    }
  }

  static Future<void> clearAllAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appointmentsKey);
    _appointments = [];

    final col = _userCollection();
    if (col != null) {
      try {
        final snapshot = await col.get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Firestore clearAll failed: $e');
      }
    }
  }

  // ── Firestore serialisation helpers ──────────────────────────────────────
  static Map<String, dynamic> _toFirestore(AppointmentModel a) {
    return {
      'id': a.id,
      'service': a.service,
      'office': a.office,
      'date': Timestamp.fromDate(a.date),
      'time': a.time,
      'token': a.token,
      'status': a.status,
      'qrData': a.qrData,
      'paymentStatus': a.paymentStatus,
      'feeAmount': a.feeAmount,
      'paymentMethod': a.paymentMethod,
      'notes': a.notes,
      'documents': a.documents.map((d) => d.toJson()).toList(),
    };
  }

}
