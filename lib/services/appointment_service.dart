import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
  static Future<List<AppointmentModel>> getAppointments() async {
    final col = _userCollection();
    if (col != null) {
      try {
        final snapshot = await col.orderBy('date', descending: true).get();
        _appointments = snapshot.docs
            .map((doc) => AppointmentModel.fromJson(_firestoreToJson(doc)))
            .toList();
        // Sync cache
        await _saveToLocal();
        return _appointments;
      } catch (e) {
        debugPrint('Firestore getAppointments failed: $e — using local cache');
      }
    }
    await _loadFromLocal();
    return _appointments;
  }

  static Future<void> addAppointment(AppointmentModel appointment) async {
    // Always write local first so the UI is responsive
    await _loadFromLocal();
    _appointments.add(appointment);
    await _saveToLocal();

    // Push to Firestore (primary citizen store)
    final col = _userCollection();
    if (col != null) {
      try {
        await col.doc(appointment.id).set(_toFirestore(appointment));
      } catch (e) {
        debugPrint('Firestore addAppointment failed: $e — kept locally');
      }
    }

    // Mirror to PostgreSQL so the web dashboard can see citizen bookings.
    // Fire-and-forget — failure never blocks the citizen.
    _mirrorToPostgres(appointment);
  }

  static Future<void> _mirrorToPostgres(AppointmentModel a) async {
    // Read citizen identity from local cache (written at login/register).
    final prefs = await SharedPreferences.getInstance();
    final nic  = prefs.getString('userNIC')  ?? '';
    final name = prefs.getString('userName') ?? '';

    http.post(
      Uri.parse('http://localhost:3000/api/web/appointments'),
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

  static Future<void> updateAppointmentStatus(String id, String status) async {
    await _loadFromLocal();
    final index = _appointments.indexWhere((a) => a.id == id);
    if (index != -1) {
      _appointments[index] = _appointments[index].copyWith(status: status);
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
  }

  static Future<void> updateAppointmentPaymentStatus(
      String id, String paymentStatus) async {
    await _loadFromLocal();
    final index = _appointments.indexWhere((a) => a.id == id);
    if (index != -1) {
      _appointments[index] =
          _appointments[index].copyWith(paymentStatus: paymentStatus);
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

  static Map<String, dynamic> _firestoreToJson(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Convert Firestore Timestamp to ISO string expected by fromJson
    if (data['date'] is Timestamp) {
      data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
    }
    return data;
  }
}
