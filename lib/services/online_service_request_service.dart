import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../config/backend_config.dart';
import '../models/online_service_request_model.dart';
import '../models/appointment_model.dart' show DocumentAttachment;

/// Citizen-side online service requests — Postgres is the source of truth
/// (read via `/api/web/online-requests/citizen/:nic`), Firestore is used
/// only for the live notification feed, exactly like [AppointmentService].
class OnlineServiceRequestService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<List<OnlineServiceRequestModel>> getRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final nic = (prefs.getString('userNIC') ?? '').toUpperCase();
    if (nic.isEmpty) return [];
    try {
      final res = await http
          .get(Uri.parse('${BackendConfig.baseUrl}/api/web/online-requests/citizen/${Uri.encodeComponent(nic)}'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final rows = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      return rows.map((r) => OnlineServiceRequestModel.fromJson(r)).toList();
    } catch (e) {
      debugPrint('OnlineServiceRequestService.getRequests error: $e');
      return [];
    }
  }

  /// Live version of [getRequests] — re-fetches whenever the backend
  /// broadcasts a change over the same Socket.IO connection
  /// [AppointmentService.watchAppointments] uses.
  static Stream<List<OnlineServiceRequestModel>> watchRequests() {
    late final StreamController<List<OnlineServiceRequestModel>> controller;
    socket_io.Socket? socket;
    int requestId = 0;

    Future<void> emitLatest() async {
      final id = ++requestId;
      try {
        final data = await getRequests();
        if (id != requestId) return;
        controller.add(data);
      } catch (e) {
        if (id != requestId) return;
        controller.addError(e);
      }
    }

    controller = StreamController<List<OnlineServiceRequestModel>>.broadcast(
      onListen: () {
        emitLatest();
        socket = socket_io.io(
          BackendConfig.baseUrl,
          socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
        );
        socket!.on('online_request_update', (_) => emitLatest());
        socket!.on('online_request_payment_confirmed', (_) => emitLatest());
        socket!.connect();
      },
      onCancel: () {
        socket?.dispose();
      },
    );
    return controller.stream;
  }

  /// Creates the request (looks up the service fee/eligibility on the
  /// backend) and uploads any attached documents linked to it. If there's a
  /// fee, the backend creates it as 'pending_payment' — invisible to staff —
  /// and only [markPaid] (called once payment actually succeeds) notifies
  /// staff and flips it to 'submitted'; a citizen can never get a service
  /// officer's attention without paying first. Free services have nothing to
  /// pay, so they're submitted and staff-notified immediately here. Returns
  /// the fee amount so the caller can decide whether to route to payment.
  static Future<double> submitRequest({
    required String id,
    required String service,
    required bool isExceptionRequest,
    String? exceptionReason,
    List<DocumentAttachment> documents = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nic = prefs.getString('userNIC') ?? '';
    final name = prefs.getString('userName') ?? '';

    final res = await http
        .post(
          Uri.parse('${BackendConfig.baseUrl}/api/web/online-requests'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': id,
            'citizen_nic': nic.isNotEmpty ? nic : null,
            'citizen_name': name.isNotEmpty ? name : null,
            'service': service,
            'is_exception_request': isExceptionRequest,
            'exception_reason': exceptionReason,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to submit request (HTTP ${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final feeAmount = double.tryParse(body['feeAmount']?.toString() ?? '') ?? 0;

    _uploadDocuments(id, documents, nic, name);

    if (feeAmount <= 0) {
      _notifyStaffOfNewRequest(service, name);
      _notifyCitizen(
        title: 'Request Submitted',
        message: 'Your online request for $service has been submitted and is awaiting review.',
      );
    }

    return feeAmount;
  }

  static Future<void> _uploadDocuments(
    String requestId,
    List<DocumentAttachment> documents,
    String nic,
    String name,
  ) async {
    for (final doc in documents) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${BackendConfig.baseUrl}/api/web/documents/upload'),
        )
          ..fields['onlineRequestId'] = requestId
          ..fields['citizenName'] = name
          ..fields['citizenNic'] = nic
          ..fields['documentType'] = doc.documentType
          ..fields['uploadedBy'] = name;
        final multipartFile = doc.bytes != null
            ? http.MultipartFile.fromBytes('file', doc.bytes!, filename: doc.fileName)
            : await http.MultipartFile.fromPath('file', doc.filePath, filename: doc.fileName);
        request.files.add(multipartFile);
        final streamed = await request.send();
        if (streamed.statusCode != 200) {
          debugPrint('Online request document upload failed (${streamed.statusCode}) for ${doc.fileName}');
        }
      } catch (e) {
        debugPrint('Online request document upload error for ${doc.fileName}: $e');
      }
    }
  }

  /// Confirms payment right after PaymentScreen succeeds — mirrors the
  /// optimistic-confirm pattern [AppointmentService] already uses instead of
  /// depending solely on the Stripe webhook. This is the point a
  /// 'pending_payment' request actually becomes 'submitted' and visible to a
  /// Service Officer for the first time.
  static Future<void> markPaid(String requestId, {required String paymentMethod, required String service}) async {
    try {
      final res = await http
          .put(
            Uri.parse('${BackendConfig.baseUrl}/api/web/online-requests/$requestId/payment-status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'paymentStatus': 'paid', 'paymentMethod': paymentMethod}),
          )
          .timeout(const Duration(seconds: 8));
      _notifyCitizen(
        title: 'Payment Confirmed',
        message: 'Your payment for this online service request has been confirmed.',
      );
      final becameSubmitted = res.statusCode == 200 &&
          (jsonDecode(res.body) as Map<String, dynamic>)['becameSubmitted'] == true;
      if (becameSubmitted) {
        final prefs = await SharedPreferences.getInstance();
        _notifyStaffOfNewRequest(service, prefs.getString('userName') ?? '');
        _notifyCitizen(
          title: 'Request Submitted',
          message: 'Your online request for $service has been submitted and is awaiting review.',
        );
      }
    } catch (e) {
      debugPrint('OnlineServiceRequestService.markPaid error: $e');
    }
  }

  static Future<void> _notifyStaffOfNewRequest(String service, String citizenName) async {
    try {
      await _db.collection('staff_notifications').add({
        'title': 'New Online Service Request',
        'message': '${citizenName.isNotEmpty ? citizenName : 'A citizen'} requested $service online.',
        'type': 'online_request',
        'action': 'View Request',
        'targetRoles': const ['serviceProcessor'],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'service': service,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyStaffOfNewRequest failed: $e');
    }
  }

  static Future<void> _notifyCitizen({required String title, required String message}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('notifications').add({
        'uid': uid,
        'title': title,
        'message': message,
        'type': 'online_request',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyCitizen failed: $e');
    }
  }
}
