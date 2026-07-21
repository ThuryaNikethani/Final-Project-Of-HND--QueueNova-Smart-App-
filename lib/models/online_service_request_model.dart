import 'dart:typed_data';

/// A citizen's request for a service handled entirely online (no physical
/// appointment) — upload documents, pay online, a Service Officer reviews
/// and forwards to the relevant office, the office produces the result, and
/// the Service Officer shares it back. Mirrors [AppointmentModel]'s shape
/// and conventions.
class OnlineServiceRequestModel {
  final String id;
  final String service;
  final double feeAmount;
  final String paymentStatus;
  final String paymentMethod;
  final String status;
  final bool isExceptionRequest;
  final String? exceptionReason;
  final String? rejectionReason;
  final String? targetDepartment;
  final String? resultDocumentId;
  final String? resultDocumentName;
  final DateTime createdAt;
  final List<OnlineRequestDocument> documents;

  OnlineServiceRequestModel({
    required this.id,
    required this.service,
    required this.feeAmount,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.status,
    required this.isExceptionRequest,
    this.exceptionReason,
    this.rejectionReason,
    this.targetDepartment,
    this.resultDocumentId,
    this.resultDocumentName,
    required this.createdAt,
    this.documents = const [],
  });

  /// Human-readable status label + who currently holds the request, both
  /// derived purely from [status] — there's no separate assignment model.
  String get statusLabel {
    switch (status) {
      case 'pending_payment':
        return 'Awaiting Payment';
      case 'submitted':
        return 'Submitted';
      case 'forwarded_to_office':
        return 'Processing';
      case 'office_completed':
        return 'Ready for Delivery';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  String get currentlyWithLabel {
    switch (status) {
      case 'pending_payment':
        return 'Waiting for your payment';
      case 'submitted':
        return 'Service Officer';
      case 'forwarded_to_office':
        return targetDepartment ?? 'Relevant Office';
      case 'office_completed':
        return 'Service Officer (finalizing)';
      case 'completed':
        return 'Completed — available to you';
      case 'rejected':
        return 'Rejected';
      default:
        return '—';
    }
  }

  factory OnlineServiceRequestModel.fromJson(Map<String, dynamic> json) {
    final docsJson = json['documents'];
    return OnlineServiceRequestModel(
      id: json['id'].toString(),
      service: json['service'] ?? '',
      feeAmount: double.tryParse(json['fee_amount']?.toString() ?? '') ?? 0,
      paymentStatus: json['payment_status'] ?? 'not_required',
      paymentMethod: json['payment_method'] ?? '',
      status: json['status'] ?? 'submitted',
      isExceptionRequest: json['is_exception_request'] == true,
      exceptionReason: json['exception_reason'],
      rejectionReason: json['rejection_reason'],
      targetDepartment: json['target_department'],
      resultDocumentId: json['result_document_id']?.toString(),
      resultDocumentName: json['result_document_name'],
      // The backend returns created_at as a UTC timestamp — .toLocal() is
      // required, otherwise dates near a local-midnight boundary can show
      // the wrong calendar day, and any future time-of-day display would
      // show the UTC clock time mislabeled as local.
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at']) ?? DateTime.now()).toLocal()
          : DateTime.now(),
      documents: docsJson is List
          ? docsJson.map((d) => OnlineRequestDocument.fromJson(d as Map<String, dynamic>)).toList()
          : const [],
    );
  }
}

class OnlineRequestDocument {
  final String id;
  final String fileName;
  final String documentType;
  final Uint8List? bytes;

  OnlineRequestDocument({
    required this.id,
    required this.fileName,
    required this.documentType,
    this.bytes,
  });

  factory OnlineRequestDocument.fromJson(Map<String, dynamic> json) {
    return OnlineRequestDocument(
      id: json['id'].toString(),
      fileName: json['document_name'] ?? json['fileName'] ?? '',
      documentType: json['document_type'] ?? json['documentType'] ?? '',
    );
  }
}
