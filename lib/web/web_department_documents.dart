import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:url_launcher/url_launcher.dart';
import 'web_api_service.dart';

/// The Department Manager's own dedicated view of documents shared with
/// them — separate from the general Document Management screen (which no
/// longer shows Approve/Reject for shared documents at all; that decision
/// belongs here now). Approving/rejecting here notifies only the Service
/// Officer who shared it — the citizen is not messaged directly from this
/// screen; relaying the outcome to the citizen is the Service Officer's own
/// follow-up action.
class WebDepartmentDocuments extends StatefulWidget {
  const WebDepartmentDocuments({super.key});

  @override
  State<WebDepartmentDocuments> createState() => _WebDepartmentDocumentsState();
}

class _WebDepartmentDocumentsState extends State<WebDepartmentDocuments> {
  String selectedFilter = 'Pending';
  final List<String> filters = ['Pending', 'Approved', 'Rejected', 'All'];

  // The office/department this manager is currently working as — mirrors
  // the office selector Queue Managers use in Queue Management, scoping
  // this screen down to only documents shared with that office.
  String selectedOffice = 'RMV - Werahera';
  final List<String> offices = [
    'RMV - Werahera',
    'Divisional Secretariat - Colombo',
    'Passport Office - Battaramulla',
    'Department of Registration',
    'NIC Service Center',
    'Immigration Department',
    'Municipal Council',
  ];

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

  Future<void> _loadDocumentsFromApi() async {
    final rows = await WebApiService.getDocuments();
    if (!mounted) return;
    setState(() {
      documents = rows
          .map((r) => {
                'id': r['id'],
                'name': r['citizen_name'] ?? '',
                'nic': r['citizen_nic'],
                'docType': r['document_type'] ?? '',
                'token': r['appointment_token'],
                'date': _formatDate(r['uploaded_at']?.toString()),
                'status': _capitalize(r['status']?.toString() ?? 'pending'),
                'file': r['document_name'] ?? '',
                'filePath': r['file_path'],
                'sharedWith': (r['shared_with'] as List?)?.cast<String>() ?? const <String>[],
                'rejectionReason': r['rejection_reason'],
              })
          // Only documents shared with the currently selected office belong
          // here — everything else stays on the general Document Management
          // screen (or belongs to a different office).
          .where((d) => (d['sharedWith'] as List).contains(selectedOffice))
          .toList();
    });
  }

  List<Map<String, dynamic>> get filteredDocuments {
    if (selectedFilter == 'All') return documents;
    return documents.where((d) => d['status'] == selectedFilter).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  /// Notifies the Service Officer role the moment a shared document is
  /// approved or rejected here — this is the only notification this screen
  /// sends; the citizen is deliberately not messaged from here.
  Future<void> _notifyServiceOfficer(Map<String, dynamic> doc, {required bool approved, String? reason}) async {
    final sharedWith = (doc['sharedWith'] as List).cast<String>();
    try {
      await FirebaseFirestore.instance.collection('staff_notifications').add({
        'title': approved ? 'Shared Document Approved' : 'Shared Document Rejected',
        'message': approved
            ? '${sharedWith.join(', ')} approved the ${doc['docType']} document for ${doc['name']}${doc['token'] != null ? ' (Token ${doc['token']})' : ''}.'
            : '${sharedWith.join(', ')} rejected the ${doc['docType']} document for ${doc['name']}${doc['token'] != null ? ' (Token ${doc['token']})' : ''}: $reason',
        'type': 'document',
        'action': 'View Document',
        'targetRoles': const ['serviceProcessor'],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyServiceOfficer failed: $e');
    }
  }

  void _approveDocument(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document: ${doc['file']}'),
            const SizedBox(height: 8),
            Text('Citizen: ${doc['name']}'),
            const SizedBox(height: 8),
            Text('Type: ${doc['docType']}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await WebApiService.approveDocument(doc['id'] as int, 'Department Manager');
              _notifyServiceOfficer(doc, approved: true);
              await _loadDocumentsFromApi();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document approved'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Approve'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document: ${doc['file']}'),
            const SizedBox(height: 8),
            Text('Citizen: ${doc['name']}'),
            const SizedBox(height: 12),
            const Text('Reason for rejection (sent to the Service Officer):'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Enter reason', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(dialogContext);
              await WebApiService.rejectDocument(doc['id'] as int, 'Department Manager', reason: reason);
              _notifyServiceOfficer(doc, approved: false, reason: reason);
              await _loadDocumentsFromApi();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document rejected'), backgroundColor: Colors.red),
              );
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showRejectionReason(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rejection Reason'),
        content: Text(doc['rejectionReason'] ?? 'No reason provided'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredDocuments;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Shared Documents'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedOffice,
                  isExpanded: true,
                  items: offices.map((office) {
                    return DropdownMenuItem(value: office, child: Text(office));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedOffice = value!);
                    _loadDocumentsFromApi();
                  },
                ),
              ),
            ),
            Row(
              children: [
                _buildStatCard('Total Documents', documents.length.toString(), Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('Pending', documents.where((d) => d['status'] == 'Pending').length.toString(), Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard('Approved', documents.where((d) => d['status'] == 'Approved').length.toString(), Colors.green),
                const SizedBox(width: 12),
                _buildStatCard('Rejected', documents.where((d) => d['status'] == 'Rejected').length.toString(), Colors.red),
                const SizedBox(width: 12),
                _buildStatCard('Shared', documents.length.toString(), const Color(0xFF1A56DB)),
              ],
            ),
            const SizedBox(height: 20),
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
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) => setState(() => selectedFilter = filter),
                    selectedColor: const Color(0xFF1A56DB),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  );
                },
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: filtered.isEmpty
                    ? const Center(child: Text('No shared documents here', style: TextStyle(color: Colors.grey)))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('Citizen Name', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('NIC', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Document Type', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Token', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Uploaded Date', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Shared With', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Department Action', style: TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: filtered.map((doc) {
                              final statusColor = _statusColor(doc['status'] as String);
                              final sharedWith = (doc['sharedWith'] as List).cast<String>();
                              return DataRow(cells: [
                                DataCell(Text(doc['name'])),
                                DataCell(Text(doc['nic'] ?? '—')),
                                DataCell(Text(doc['docType'])),
                                DataCell(Text(doc['token'] ?? '—')),
                                DataCell(Text(doc['date'])),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(doc['status'], style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                                DataCell(Text(sharedWith.join(', '))),
                                // Actions — view only.
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.visibility, size: 18, color: Colors.blue),
                                    tooltip: 'View document',
                                    onPressed: doc['filePath'] == null
                                        ? null
                                        : () => launchUrl(
                                              Uri.parse('${WebApiService.apiOrigin}/api/web/documents/download/${doc['id']}'),
                                              webOnlyWindowName: '_blank',
                                            ),
                                  ),
                                ),
                                // Department Action — the decision only the
                                // Department Manager makes on a shared document.
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Pending and Approved both stay
                                      // actionable — documents already
                                      // marked Approved may have been
                                      // approved by the Service Officer
                                      // before this screen existed, not
                                      // actually verified by the
                                      // department, so the department must
                                      // still be able to review/correct them.
                                      if (doc['status'] == 'Pending' || doc['status'] == 'Approved') ...[
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                                          tooltip: 'Approve',
                                          onPressed: () => _approveDocument(doc),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                          tooltip: 'Reject',
                                          onPressed: () => _rejectDocument(doc),
                                        ),
                                      ],
                                      if (doc['status'] == 'Rejected' && doc['rejectionReason'] != null)
                                        IconButton(
                                          icon: const Icon(Icons.info_outline, size: 18, color: Colors.red),
                                          tooltip: 'View rejection reason',
                                          onPressed: () => _showRejectionReason(doc),
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
}
