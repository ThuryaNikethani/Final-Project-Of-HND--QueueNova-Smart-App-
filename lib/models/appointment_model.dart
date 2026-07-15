import 'dart:typed_data';

class AppointmentModel {
  final String id;
  final String service;
  final String office;
  final DateTime date;
  final String time;
  final String token;
  String status;
  final String qrData;
  final String paymentStatus;
  final double feeAmount;
  final String paymentMethod;
  final String? notes;
  final List<DocumentAttachment> documents;

  AppointmentModel({
    required this.id,
    required this.service,
    required this.office,
    required this.date,
    required this.time,
    required this.token,
    required this.status,
    required this.qrData,
    required this.paymentStatus,
    required this.feeAmount,
    required this.paymentMethod,
    this.notes,
    this.documents = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service': service,
      'office': office,
      'date': date.toIso8601String(),
      'time': time,
      'token': token,
      'status': status,
      'qrData': qrData,
      'paymentStatus': paymentStatus,
      'feeAmount': feeAmount,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'documents': documents.map((d) => d.toJson()).toList(),
    };
  }

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'],
      service: json['service'],
      office: json['office'],
      date: DateTime.parse(json['date']),
      time: json['time'],
      token: json['token'],
      status: json['status'],
      qrData: json['qrData'],
      paymentStatus: json['paymentStatus'],
      feeAmount: json['feeAmount'].toDouble(),
      paymentMethod: json['paymentMethod'],
      notes: json['notes'],
      documents: json['documents'] != null
          ? (json['documents'] as List)
              .map((d) => DocumentAttachment.fromJson(d))
              .toList()
          : [],
    );
  }

  AppointmentModel copyWith({
    String? status,
    String? paymentStatus,
  }) {
    return AppointmentModel(
      id: id,
      service: service,
      office: office,
      date: date,
      time: time,
      token: token,
      status: status ?? this.status,
      qrData: qrData,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      feeAmount: feeAmount,
      paymentMethod: paymentMethod,
      notes: notes,
      documents: documents,
    );
  }

  void addDocument({
    required String docId,
    required String fileName,
    required String filePath,
    required String documentType,
    required bool isRequired,
  }) {
    documents.add(DocumentAttachment(
      id: docId,
      fileName: fileName,
      filePath: filePath,
      documentType: documentType,
      isRequired: isRequired,
      uploadedAt: DateTime.now(),
    ));
  }
}

class DocumentAttachment {
  final String id;
  final String fileName;
  final String filePath;
  final String documentType;
  final bool isRequired;
  final DateTime uploadedAt;
  // In-memory only (not serialized to JSON/Firestore — would bloat local
  // storage). On Flutter Web there's no real filesystem, so `filePath` isn't
  // readable; the actual upload to the backend reads these bytes instead.
  final Uint8List? bytes;

  DocumentAttachment({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.documentType,
    required this.isRequired,
    required this.uploadedAt,
    this.bytes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'documentType': documentType,
      'isRequired': isRequired,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  factory DocumentAttachment.fromJson(Map<String, dynamic> json) {
    return DocumentAttachment(
      id: json['id'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      documentType: json['documentType'],
      isRequired: json['isRequired'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }
}