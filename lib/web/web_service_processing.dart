import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebServiceProcessing extends StatefulWidget {
  const WebServiceProcessing({super.key});

  @override
  State<WebServiceProcessing> createState() => _WebServiceProcessingState();
}

class _WebServiceProcessingState extends State<WebServiceProcessing> {
  String selectedFilter = 'Pending';
  final List<String> filters = ['Pending', 'Processing', 'Approved', 'Rejected', 'All'];
  int pendingCount = 0;

  List<Map<String, dynamic>> requests = [];
  socket_io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadRequestsFromApi();
    _socket = socket_io.io(
      WebApiService.apiOrigin,
      socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket!.on('document_update', (_) => _loadRequestsFromApi());
    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return DateFormat('d MMM yyyy, hh:mm a').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Future<void> _loadRequestsFromApi() async {
    final rows = await WebApiService.getServiceRequests();
    if (!mounted) return;
    setState(() {
      requests = rows.map((r) {
        final docNames = (r['documents'] as List?)?.cast<String>() ?? const <String>[];
        final docIds = (r['doc_ids'] as List?) ?? const [];
        return {
          'id': r['id'],
          'citizen': r['citizen_name'] ?? '',
          'nic': r['citizen_nic'],
          'service': r['service'] ?? '',
          'date': _formatDate(r['date']?.toString()),
          'status': _capitalize(r['status']?.toString() ?? 'pending'),
          'paymentStatus': r['payment_status'] ?? 'pending',
          'fee': r['fee_amount'] ?? 0,
          'documents': docNames,
          'docUrls': docIds,
          'comments': r['comments'] ?? '',
          'processedBy': r['processed_by'] ?? '',
          'processedAt': _formatDateTime(r['processed_at']?.toString()),
        };
      }).toList();
      _updatePendingCount();
    });
  }

  void _updatePendingCount() {
    pendingCount = requests.where((r) => r['status'] == 'Pending').length;
  }

  List<Map<String, dynamic>> get filteredRequests {
    if (selectedFilter == 'All') {
      return requests;
    }
    return requests.where((r) => r['status'] == selectedFilter).toList();
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Processing': return Colors.blue;
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Pending': return 'web_status_pending'.tr();
      case 'Processing': return 'web_status_processing'.tr();
      case 'Approved': return 'web_status_approved'.tr();
      case 'Rejected': return 'web_status_rejected'.tr();
      case 'All': return 'web_status_all'.tr();
      default: return status;
    }
  }

  Color getPaymentColor(String paymentStatus) {
    return paymentStatus == 'paid' ? Colors.green : Colors.orange;
  }

  void _showDocumentViewer(Map<String, dynamic> request, String docName, int? docId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('web_document_colon'.tr(args: [docName]), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 20),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('web_doc_preview_placeholder'.tr()),
                      Text('web_click_download_hint'.tr(), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: docId == null
                        ? null
                        : () => launchUrl(
                              Uri.parse('${WebApiService.apiOrigin}/api/web/documents/download/$docId'),
                              webOnlyWindowName: '_blank',
                            ),
                    icon: const Icon(Icons.download),
                    label: Text('web_download'.tr()),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: Text('close'.tr()),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareDialog(Map<String, dynamic> request) {
    final List<String> departments = [
      'RMV - Werahera',
      'Divisional Secretariat - Colombo',
      'Passport Office - Battaramulla',
      'Department of Registration',
      'NIC Service Center',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('web_share_documents_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('web_share_documents_desc'.tr(), style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ...departments.map((dept) => ListTile(
              leading: const Icon(Icons.business, color: Color(0xFF1A56DB)),
              title: Text(dept),
              trailing: const Icon(Icons.share),
              onTap: () async {
                Navigator.pop(context);
                await WebApiService.shareServiceRequest(request['id'] as String, [dept], sharedBy: 'Service Officer');
                await _loadRequestsFromApi();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('web_documents_shared_with'.tr(args: [dept])), backgroundColor: Colors.green),
                );
              },
            )),
          ],
        ),
      ),
    );
  }

  /// Notifies the citizen identified by [nic] via the `notifications`
  /// collection (the same one the citizen app's Notifications screen reads
  /// live). Looks the uid up through `nic_index`, same as login does.
  Future<void> _notifyCitizenByNic({
    required String? nic,
    required String title,
    required String message,
  }) async {
    if (nic == null || nic.isEmpty) return;
    try {
      final indexDoc = await FirebaseFirestore.instance.collection('nic_index').doc(nic.toUpperCase()).get();
      final uid = indexDoc.data()?['uid'] as String?;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('notifications').add({
        'uid': uid,
        'title': title,
        'message': message,
        'type': 'appointment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyCitizenByNic error: $e');
    }
  }

  void _showRejectDialog(Map<String, dynamic> request) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_reject_application_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('web_reject_reason_prompt'.tr()),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'web_enter_rejection_reason_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text;
              Navigator.pop(context);
              await WebApiService.rejectServiceRequest(request['id'] as String, 'Service Officer', reason: reason);
              _notifyCitizenByNic(
                nic: request['nic'] as String?,
                title: 'Application Rejected',
                message: 'Your ${request['service']} application has been rejected. Reason: $reason',
              );
              await _loadRequestsFromApi();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('web_application_rejected'.tr()), backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('web_reject_button'.tr()),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_approve_application_title'.tr()),
        content: Text('web_approve_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await WebApiService.approveServiceRequest(request['id'] as String, 'Service Officer');
              _notifyCitizenByNic(
                nic: request['nic'] as String?,
                title: 'Application Approved',
                message: 'Your ${request['service']} application has been approved.',
              );
              await _loadRequestsFromApi();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('web_application_approved'.tr()), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('web_approve_button'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = filteredRequests;

    return Scaffold(
      appBar: AppBar(
        title: Text('web_menu_service_processing'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 20),
              child: Stack(
                children: [
                  const Icon(Icons.notifications_none, size: 24),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatCard('web_status_pending'.tr(), requests.where((r) => r['status'] == 'Pending').length.toString(), Colors.orange),
                const SizedBox(width: 16),
                _buildStatCard('web_status_processing'.tr(), requests.where((r) => r['status'] == 'Processing').length.toString(), Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard('web_status_approved'.tr(), requests.where((r) => r['status'] == 'Approved').length.toString(), Colors.green),
                const SizedBox(width: 16),
                _buildStatCard('web_status_rejected'.tr(), requests.where((r) => r['status'] == 'Rejected').length.toString(), Colors.red),
                const SizedBox(width: 16),
                _buildStatCard('web_pending_payments'.tr(), requests.where((r) => r['paymentStatus'] == 'pending').length.toString(), Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 45,
              margin: const EdgeInsets.only(bottom: 20),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final isSelected = selectedFilter == filter;
                  return FilterChip(
                    label: Text(_statusLabel(filter)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => selectedFilter = filter),
                    selectedColor: const Color(0xFF1A56DB),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final request = filteredList[index];
                  final statusColor = getStatusColor(request['status']);
                  final paymentColor = getPaymentColor(request['paymentStatus']);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.request_page, color: statusColor),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request['service'],
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'web_request_id_label'.tr(args: ['${request['id']}']),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: paymentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        request['paymentStatus'] == 'paid' ? Icons.check_circle : Icons.pending,
                                        size: 14,
                                        color: paymentColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        request['paymentStatus'] == 'paid' ? 'web_paid'.tr() : 'web_payment_pending_short'.tr(),
                                        style: TextStyle(fontSize: 12, color: paymentColor, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel(request['status']),
                                    style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildInfoRow('web_citizen_name'.tr(), request['citizen'])),
                            Expanded(child: _buildInfoRow('web_nic_number'.tr(), request['nic'] ?? '—')),
                            Expanded(child: _buildInfoRow('web_request_date'.tr(), request['date'])),
                            Expanded(child: _buildInfoRow('web_fee_label'.tr(), 'Rs. ${request['fee']}')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDocumentsSection(request),
                        const SizedBox(height: 16),
                        if (request['processedBy'].isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.history, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('web_processed_by_label'.tr(args: ['${request['processedBy']}'])),
                                const SizedBox(width: 16),
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('web_processed_at_label'.tr(args: ['${request['processedAt']}'])),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (request['comments'].isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.comment, size: 16, color: statusColor),
                                const SizedBox(width: 8),
                                Expanded(child: Text(request['comments'], style: TextStyle(color: statusColor))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (request['status'] == 'Pending' || request['status'] == 'Processing')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showShareDialog(request),
                                icon: const Icon(Icons.share),
                                label: Text('web_share_button'.tr()),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue)),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => _showRejectDialog(request),
                                icon: const Icon(Icons.close),
                                label: Text('web_reject_button'.tr()),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showApproveDialog(request),
                                icon: const Icon(Icons.check),
                                label: Text('web_approve_button'.tr()),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDocumentsSection(Map<String, dynamic> request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('web_uploaded_documents'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(request['documents'].length, (index) {
            final docName = request['documents'][index];
            final docUrls = request['docUrls'] as List;
            final docId = index < docUrls.length ? docUrls[index] as int? : null;
            return GestureDetector(
              onTap: () => _showDocumentViewer(request, docName, docId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file, size: 14, color: Color(0xFF1A56DB)),
                    const SizedBox(width: 4),
                    Text(docName, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.visibility, size: 14, color: Color(0xFF1A56DB)),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}