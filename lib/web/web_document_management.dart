import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebDocumentManagement extends StatefulWidget {
  const WebDocumentManagement({super.key});

  @override
  State<WebDocumentManagement> createState() => _WebDocumentManagementState();
}

class _WebDocumentManagementState extends State<WebDocumentManagement> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Pending', 'Approved', 'Rejected', 'Shared'];

  List<Map<String, dynamic>> documents = [];
  socket_io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadDocumentsFromApi();
    _socket = socket_io.io(
      WebApiService.apiOrigin,
      socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket!.on('document_update', (_) => _loadDocumentsFromApi());
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
    if (iso == null) return '';
    try {
      return DateFormat('d MMM yyyy, hh:mm a').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Pending': return 'web_status_pending'.tr();
      case 'Approved': return 'web_status_approved'.tr();
      case 'Rejected': return 'web_status_rejected'.tr();
      case 'All': return 'web_status_all'.tr();
      case 'Shared': return 'web_status_shared'.tr();
      default: return status;
    }
  }

  Future<void> _loadDocumentsFromApi() async {
    final rows = await WebApiService.getDocuments();
    if (!mounted) return;
    setState(() {
      documents = rows.map((r) {
        final sharedWith = (r['shared_with'] as List?)?.cast<String>() ?? const <String>[];
        return {
          'id': r['id'],
          'name': r['citizen_name'] ?? '',
          'nic': r['citizen_nic'],
          'docType': r['document_type'] ?? '',
          'date': _formatDate(r['uploaded_at']?.toString()),
          'status': _capitalize(r['status']?.toString() ?? 'pending'),
          'file': r['document_name'] ?? '',
          'filePath': r['file_path'],
          'sharedWith': sharedWith,
          'sharedCount': sharedWith.length,
          'rejectionReason': r['rejection_reason'],
          'reviewedBy': r['reviewed_by_name'],
          'reviewedAt': _formatDateTime(r['reviewed_at']?.toString()),
        };
      }).toList();
    });
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
        'type': 'document',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyCitizenByNic error: $e');
    }
  }

  final List<Map<String, dynamic>> departments = [
    {'name': 'RMV - Werahera', 'icon': Icons.directions_car, 'color': const Color(0xFF1A56DB)},
    {'name': 'Divisional Secretariat - Colombo', 'icon': Icons.business, 'color': const Color(0xFF10B981)},
    {'name': 'Passport Office - Battaramulla', 'icon': Icons.airplane_ticket, 'color': const Color(0xFFF59E0B)},
    {'name': 'Department of Registration', 'icon': Icons.assignment, 'color': const Color(0xFF8B5CF6)},
    {'name': 'NIC Service Center', 'icon': Icons.badge, 'color': const Color(0xFF06B6D4)},
    {'name': 'Immigration Department', 'icon': Icons.book, 'color': const Color(0xFFEF4444)},
    {'name': 'Municipal Council', 'icon': Icons.location_city, 'color': const Color(0xFF6B7280)},
  ];

  // ==================== APPROVAL/REJECTION METHODS ====================

  void _approveDocument(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('web_approve_document_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('web_document_colon'.tr(args: ['${doc['file']}'])),
            const SizedBox(height: 8),
            Text('web_citizen_label'.tr(args: ['${doc['name']}'])),
            const SizedBox(height: 8),
            Text('web_type_label'.tr(args: ['${doc['docType']}'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await WebApiService.approveDocument(doc['id'] as int, 'Document Officer');
              _notifyCitizenByNic(
                nic: doc['nic'] as String?,
                title: 'Document Approved',
                message: 'Your ${doc['docType']} document has been approved.',
              );
              await _loadDocumentsFromApi();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('web_document_approved_success'.tr()),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text('web_approve_button'.tr()),
          ),
        ],
      ),
    );
  }

  void _rejectDocument(Map<String, dynamic> doc) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('web_reject_document_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('web_document_colon'.tr(args: ['${doc['file']}'])),
            const SizedBox(height: 8),
            Text('web_citizen_label'.tr(args: ['${doc['name']}'])),
            const SizedBox(height: 12),
            Text('web_reject_reason_prompt'.tr()),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'web_reason_for_rejection_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('web_provide_rejection_reason_snackbar'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              await WebApiService.rejectDocument(doc['id'] as int, 'Document Officer', reason: reason);
              _notifyCitizenByNic(
                nic: doc['nic'] as String?,
                title: 'Document Rejected',
                message: 'Your ${doc['docType']} document was rejected. Reason: $reason',
              );
              await _loadDocumentsFromApi();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('web_document_rejected_success'.tr()),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('web_reject_button'.tr()),
          ),
        ],
      ),
    );
  }

  void _showRejectionReason(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('web_rejection_reason_title'.tr()),
        content: Text(doc['rejectionReason'] ?? 'web_no_reason_provided'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(Map<String, dynamic> doc) {
    List<String> tempSelectedDepartments = List.from(doc['sharedWith']);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A56DB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.share, color: Color(0xFF1A56DB)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'web_cross_dept_sharing_title'.tr(),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('web_document_colon'.tr(args: ['${doc['file']}']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('web_citizen_label'.tr(args: ['${doc['name']} (${doc['nic'] ?? '—'})']), style: const TextStyle(fontSize: 12)),
                        Text('web_document_type_label'.tr(args: ['${doc['docType']}']), style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: doc['status'] == 'Approved' ? Colors.green.withOpacity(0.1) : 
                                    doc['status'] == 'Rejected' ? Colors.red.withOpacity(0.1) : 
                                    Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'web_status_colon_label'.tr(args: [_statusLabel(doc['status'] as String)]),
                            style: TextStyle(
                              fontSize: 11,
                              color: doc['status'] == 'Approved' ? Colors.green : 
                                     doc['status'] == 'Rejected' ? Colors.red : 
                                     Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'web_share_with_departments'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'web_select_departments_hint'.tr(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(dialogContext).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: departments.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final dept = departments[index];
                        final isSelected = tempSelectedDepartments.contains(dept['name']);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (bool? checked) {
                            setModalState(() {
                              if (checked == true) {
                                tempSelectedDepartments.add(dept['name']);
                              } else {
                                tempSelectedDepartments.remove(dept['name']);
                              }
                            });
                          },
                          title: Text(dept['name']),
                          secondary: Icon(dept['icon'], color: dept['color']),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: const Color(0xFF1A56DB),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF1A56DB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'web_shared_docs_accessible_hint'.tr(),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF1A56DB)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('cancel'.tr()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            await WebApiService.shareDocument(
                              doc['id'] as int,
                              tempSelectedDepartments,
                              sharedBy: 'Document Officer',
                            );
                            await _loadDocumentsFromApi();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('web_document_shared_count'.tr(args: ['${tempSelectedDepartments.length}'])),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56DB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('web_share_document_button'.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocs = selectedFilter == 'All' 
        ? documents 
        : selectedFilter == 'Shared'
            ? documents.where((d) => d['sharedCount'] > 0).toList()
            : documents.where((d) => d['status'] == selectedFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('web_document_management_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Stats Cards
            Row(
              children: [
                _buildStatCard('web_total_documents'.tr(), documents.length.toString(), Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('web_status_pending'.tr(),
                    documents.where((d) => d['status'] == 'Pending').length.toString(),
                    Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard('web_status_approved'.tr(),
                    documents.where((d) => d['status'] == 'Approved').length.toString(),
                    Colors.green),
                const SizedBox(width: 12),
                _buildStatCard('web_status_rejected'.tr(),
                    documents.where((d) => d['status'] == 'Rejected').length.toString(),
                    Colors.red),
                const SizedBox(width: 12),
                _buildStatCard('web_status_shared'.tr(),
                    documents.where((d) => d['sharedCount'] > 0).length.toString(),
                    const Color(0xFF1A56DB)),
              ],
            ),
            const SizedBox(height: 20),
            // Filter Chips
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
            // Documents Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columnSpacing: 16,
                      dataRowHeight: 60,
                      columns: [
                        DataColumn(label: Text('web_citizen_name'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('web_col_nic'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('web_col_document_type'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('web_col_upload_date'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('web_col_status'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('web_col_shared_with'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('web_col_actions'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                      ],
                      rows: filteredDocs.map((doc) {
                        Color statusColor = doc['status'] == 'Approved' 
                            ? Colors.green 
                            : (doc['status'] == 'Pending' ? Colors.orange : Colors.red);
                        return DataRow(cells: [
                          DataCell(Text(doc['name'])),
                          DataCell(Text(doc['nic'] ?? '—')),
                          DataCell(Text(doc['docType'])),
                          DataCell(Text(doc['date'])),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    doc['status'] == 'Approved' ? Icons.check_circle : 
                                    (doc['status'] == 'Pending' ? Icons.pending : Icons.cancel),
                                    size: 14,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(_statusLabel(doc['status'] as String),
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            doc['sharedCount'] == 0
                                ? Text('web_not_shared'.tr(), style: const TextStyle(color: Colors.grey))
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A56DB).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'web_dept_count'.tr(args: ['${doc['sharedCount']}']),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF1A56DB)),
                                    ),
                                  ),
                          ),
                          DataCell(
                            Wrap(
                              spacing: 4,
                              children: [
                                // View Document
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 18, color: Colors.blue),
                                  onPressed: () {
                                    if (doc['filePath'] == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('web_no_file_attached'.tr())),
                                      );
                                      return;
                                    }
                                    launchUrl(
                                      Uri.parse('${WebApiService.apiOrigin}/api/web/documents/download/${doc['id']}'),
                                      webOnlyWindowName: '_blank',
                                    );
                                  },
                                  tooltip: 'web_view_document_tooltip'.tr(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                // Approve Button (only for pending)
                                if (doc['status'] == 'Pending') ...[
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                                    onPressed: () => _approveDocument(doc),
                                    tooltip: 'web_approve_tooltip'.tr(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                    onPressed: () => _rejectDocument(doc),
                                    tooltip: 'web_reject_tooltip'.tr(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                                // Rejection Reason (only for rejected)
                                if (doc['status'] == 'Rejected' && doc['rejectionReason'] != null)
                                  IconButton(
                                    icon: const Icon(Icons.info_outline, size: 18, color: Colors.red),
                                    onPressed: () => _showRejectionReason(doc),
                                    tooltip: 'web_view_rejection_reason_tooltip'.tr(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                // Share Button
                                IconButton(
                                  icon: const Icon(Icons.share, size: 18, color: Color(0xFF1A56DB)),
                                  onPressed: () => _showShareDialog(doc),
                                  tooltip: 'web_cross_dept_sharing_title'.tr(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}