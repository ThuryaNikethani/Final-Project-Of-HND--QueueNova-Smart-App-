import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'web_api_service.dart';
import 'web_role_model.dart';

/// Citizen-initiated online service requests (no physical appointment).
/// Role-aware: a Service Officer reviews a submitted request (including any
/// exception reason for a service that isn't normally online-eligible) and
/// accepts — forwarding it to the relevant office in the same action — or
/// rejects; the relevant office (Department Manager) uploads the finished
/// result; the Service Officer then shares it back with the citizen.
class WebOnlineServiceRequests extends StatefulWidget {
  final UserRole userRole;
  final String staffId;
  final String staffName;

  const WebOnlineServiceRequests({
    super.key,
    required this.userRole,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<WebOnlineServiceRequests> createState() => _WebOnlineServiceRequestsState();
}

class _WebOnlineServiceRequestsState extends State<WebOnlineServiceRequests> {
  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> departments = [];
  socket_io.Socket? _socket;
  String selectedFilter = '';

  bool get _isOfficer => widget.userRole == UserRole.serviceProcessor;
  bool get _isOffice => widget.userRole == UserRole.departmentManager;

  List<String> get filters => _isOfficer
      ? ['Awaiting Review', 'Awaiting Delivery', 'All']
      : ['Incoming', 'All'];

  @override
  void initState() {
    super.initState();
    selectedFilter = filters.first;
    _load();
    WebApiService.getDepartments().then((rows) {
      if (mounted) setState(() => departments = rows);
    });
    _socket = socket_io.io(
      WebApiService.apiOrigin,
      socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket!.on('online_request_update', (_) => _load());
    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await WebApiService.getOnlineRequests();
    if (!mounted) return;
    setState(() => requests = rows);
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      // The backend returns created_at as a UTC timestamp — .toLocal() is
      // required, otherwise this prints the UTC wall-clock time mislabeled
      // as if it were the officer's local time.
      return DateFormat('d MMM yyyy, hh:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  List<Map<String, dynamic>> get filteredRequests {
    switch (selectedFilter) {
      case 'Awaiting Review':
        return requests.where((r) => r['status'] == 'submitted').toList();
      case 'Awaiting Delivery':
        return requests.where((r) => r['status'] == 'office_completed').toList();
      case 'Incoming':
        return requests.where((r) => r['status'] == 'forwarded_to_office').toList();
      default:
        return requests;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_payment': return Colors.orange;
      case 'submitted': return Colors.blue;
      case 'forwarded_to_office': return const Color(0xFF1A56DB);
      case 'office_completed': return Colors.purple;
      case 'completed': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_payment': return 'Awaiting Payment';
      case 'submitted': return 'Submitted';
      case 'forwarded_to_office': return 'Processing';
      case 'office_completed': return 'Ready for Delivery';
      case 'completed': return 'Completed';
      case 'rejected': return 'Rejected';
      default: return status;
    }
  }

  /// Notifies the citizen via the same live `notifications` collection the
  /// citizen app reads, resolving their uid through `nic_index`.
  Future<void> _notifyCitizenByNic({required String? nic, required String title, required String message}) async {
    if (nic == null || nic.isEmpty) return;
    try {
      final indexDoc = await FirebaseFirestore.instance.collection('nic_index').doc(nic.toUpperCase()).get();
      final uid = indexDoc.data()?['uid'] as String?;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('notifications').add({
        'uid': uid,
        'title': title,
        'message': message,
        'type': 'online_request',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyCitizenByNic error: $e');
    }
  }

  Future<void> _notifyStaffRole(String role, {required String title, required String message}) async {
    try {
      await FirebaseFirestore.instance.collection('staff_notifications').add({
        'title': title,
        'message': message,
        'type': 'online_request',
        'action': 'View Request',
        'targetRoles': [role],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyStaffRole error: $e');
    }
  }

  void _showRejectDialog(Map<String, dynamic> request) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejecting this request.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Rejection reason', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final reason = controller.text.trim();
              Navigator.pop(context);
              await WebApiService.rejectOnlineRequest(
                request['id'] as String,
                staffId: widget.staffId,
                staffName: widget.staffName,
                reason: reason,
              );
              _notifyCitizenByNic(
                nic: request['citizen_nic'] as String?,
                title: 'Online Request Rejected',
                message: 'Your ${request['service']} online request was rejected. Reason: $reason',
              );
              await _load();
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showAcceptDialog(Map<String, dynamic> request) {
    String? targetDept = departments.isNotEmpty ? departments.first['name'] as String? : null;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Accept & Forward to Office'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will accept the request and forward the citizen\'s documents to the selected office.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: targetDept,
                decoration: const InputDecoration(labelText: 'Relevant Office', border: OutlineInputBorder()),
                items: departments
                    .map((d) => DropdownMenuItem(value: d['name'] as String, child: Text(d['name'] as String)))
                    .toList(),
                onChanged: (v) => setDialogState(() => targetDept = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: targetDept == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await WebApiService.acceptOnlineRequest(
                        request['id'] as String,
                        staffId: widget.staffId,
                        staffName: widget.staffName,
                        targetDepartment: targetDept!,
                      );
                      _notifyCitizenByNic(
                        nic: request['citizen_nic'] as String?,
                        title: 'Online Request Accepted',
                        message: 'Your ${request['service']} online request has been accepted and forwarded to $targetDept.',
                      );
                      _notifyStaffRole(
                        'departmentManager',
                        title: 'Online Request Forwarded',
                        message: '${request['citizen_name']}\'s ${request['service']} request needs processing.',
                      );
                      await _load();
                    },
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadResult(Map<String, dynamic> request) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (!mounted) return;
    final ok = await WebApiService.completeOnlineRequestAtOffice(
      request['id'] as String,
      staffId: widget.staffId,
      staffName: widget.staffName,
      citizenName: request['citizen_name'] as String? ?? '',
      citizenNic: request['citizen_nic'] as String? ?? '',
      fileBytes: file.bytes!,
      fileName: file.name,
    );
    if (!mounted) return;
    if (ok) {
      _notifyStaffRole(
        'serviceProcessor',
        title: 'Result Ready to Deliver',
        message: '${request['citizen_name']}\'s ${request['service']} result is ready to share with the citizen.',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result document uploaded'), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deliverToCitizen(Map<String, dynamic> request) async {
    await WebApiService.deliverOnlineRequest(request['id'] as String, staffId: widget.staffId, staffName: widget.staffName);
    _notifyCitizenByNic(
      nic: request['citizen_nic'] as String?,
      title: 'Your Request is Complete',
      message: 'Your ${request['service']} online request is complete. The result is now available.',
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shared with citizen'), backgroundColor: Colors.green),
    );
  }

  void _showEligibilitySheet() async {
    final services = await WebApiService.getServicesCatalog();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Online Eligibility per Service', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Turn a service off to require citizens to justify an online request (e.g. a court ruling) instead of visiting in person.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final s = services[index];
                    final eligible = s['online_eligible'] != false;
                    return SwitchListTile(
                      title: Text(s['name'] as String? ?? ''),
                      value: eligible,
                      onChanged: (v) async {
                        await WebApiService.setServiceOnlineEligible(s['id'] as int, v);
                        setSheetState(() => s['online_eligible'] = v);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredRequests;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Service Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isOfficer)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: TextButton.icon(
                onPressed: _showEligibilitySheet,
                icon: const Icon(Icons.tune),
                label: const Text('Online Eligibility'),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
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
              child: filtered.isEmpty
                  ? const Center(child: Text('No requests here', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _buildRequestCard(filtered[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String? ?? 'submitted';
    final color = _statusColor(status);
    final docs = (request['documents'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final isException = request['is_exception_request'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
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
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.cloud_done, color: color),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request['service'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Request #${request['id']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _infoRow('Citizen', request['citizen_name'] as String? ?? '')),
              Expanded(child: _infoRow('NIC', request['citizen_nic'] as String? ?? '—')),
              Expanded(child: _infoRow('Submitted', _formatDate(request['created_at']?.toString()))),
              Expanded(child: _infoRow('Fee', 'Rs. ${request['fee_amount'] ?? 0} (${request['payment_status']})')),
            ],
          ),
          if (isException) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.gavel, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exception request — reason given: ${request['exception_reason'] ?? ''}',
                      style: const TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Citizen Documents', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: docs.map((d) => _docChip(d['document_name'] as String? ?? '', d['id'])).toList(),
            ),
          ],
          if (request['result_document_name'] != null) ...[
            const SizedBox(height: 12),
            const Text('Result Document', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _docChip(request['result_document_name'] as String, request['result_document_id']),
          ],
          if (status == 'rejected' && (request['rejection_reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: Text('Rejected: ${request['rejection_reason']}', style: const TextStyle(color: Colors.red)),
            ),
          ],
          if (status == 'forwarded_to_office' && (request['target_department'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Forwarded to: ${request['target_department']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 16),
          _buildActions(request, status),
        ],
      ),
    );
  }

  Widget _buildActions(Map<String, dynamic> request, String status) {
    final buttons = <Widget>[];

    if (_isOfficer && status == 'submitted') {
      buttons.addAll([
        OutlinedButton.icon(
          onPressed: () => _showRejectDialog(request),
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _showAcceptDialog(request),
          icon: const Icon(Icons.check),
          label: const Text('Accept & Forward'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ]);
    } else if (_isOfficer && status == 'office_completed') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _deliverToCitizen(request),
          icon: const Icon(Icons.send),
          label: const Text('Share with Citizen'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
        ),
      );
    } else if (_isOffice && status == 'forwarded_to_office') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _uploadResult(request),
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Result & Complete'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: buttons);
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _docChip(String name, dynamic docId) {
    return GestureDetector(
      onTap: docId == null
          ? null
          : () => launchUrl(
                Uri.parse('${WebApiService.apiOrigin}/api/web/documents/download/$docId'),
                webOnlyWindowName: '_blank',
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 14, color: Color(0xFF1A56DB)),
            const SizedBox(width: 4),
            Text(name, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.download, size: 14, color: Color(0xFF1A56DB)),
          ],
        ),
      ),
    );
  }
}
