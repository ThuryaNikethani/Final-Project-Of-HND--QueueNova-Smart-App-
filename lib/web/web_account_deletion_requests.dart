import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebAccountDeletionRequests extends StatefulWidget {
  final String officerName;

  const WebAccountDeletionRequests({super.key, required this.officerName});

  @override
  State<WebAccountDeletionRequests> createState() => _WebAccountDeletionRequestsState();
}

class _WebAccountDeletionRequestsState extends State<WebAccountDeletionRequests> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Pending', 'Approved', 'Rejected'];

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collection('account_deletion_requests')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final docs = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList()
        ..sort((a, b) {
          final aTime = a['requestedAt'] as Timestamp?;
          final bTime = b['requestedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
      setState(() {
        _requests = docs;
        _loading = false;
        _error = null;
      });
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _notifyCitizen(Map<String, dynamic> req, {
    required String title,
    required String message,
  }) async {
    final uid = req['uid'] as String?;
    if (uid == null || uid.isEmpty) return;
    await FirebaseFirestore.instance.collection('notifications').add({
      'uid': uid,
      'title': title,
      'message': message,
      'type': 'account_deletion',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final userData = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data();

    final phone = _normalizePhone(userData?['phone'] as String?);
    if (phone != null) {
      final result = await WebApiService.sendSms(phone, '$title: $message');
      await _logDelivery(uid: uid, channel: 'sms', recipient: phone, title: title, message: message, result: result);
    }

    final tokens = (userData?['fcmTokens'] as List?)?.cast<String>();
    if (tokens != null && tokens.isNotEmpty) {
      final result = await WebApiService.sendPush(tokens, title, message);
      await _logDelivery(uid: uid, channel: 'push', recipient: '${tokens.length} device(s)', title: title, message: message, result: result);
    }
  }

  /// Audit trail of every SMS/push send attempt, so staff can tell whether a
  /// citizen actually received a notification rather than just seeing it was
  /// queued.
  Future<void> _logDelivery({
    required String uid,
    required String channel,
    required String recipient,
    required String title,
    required String message,
    required SendResult result,
  }) async {
    await FirebaseFirestore.instance.collection('notification_delivery_logs').add({
      'uid': uid,
      'channel': channel,
      'recipient': recipient,
      'title': title,
      'message': message,
      'success': result.success,
      'error': result.error,
      'context': 'account_deletion',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Normalizes a Sri Lankan phone number (e.g. `0771234567` or `94771234567`)
  /// to the E.164 format (`+94771234567`) Twilio requires.
  String? _normalizePhone(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = '94${digits.substring(1)}';
    if (!digits.startsWith('94')) digits = '94$digits';
    return '+$digits';
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'all': return 'web_status_all'.tr();
      case 'pending': return 'pending'.tr();
      case 'approved': return 'web_status_approved'.tr();
      case 'rejected': return 'web_status_rejected'.tr();
      default: return status;
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> req) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('web_approve_deletion_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('web_citizen_label'.tr(args: ['${req['name'] ?? 'web_unknown'.tr()}'])),
            const SizedBox(height: 8),
            Text('web_nic_colon_label'.tr(args: ['${req['nic'] ?? '—'}'])),
            if ((req['reason'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('web_reason_label'.tr(args: ['${req['reason']}'])),
            ],
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
              await FirebaseFirestore.instance
                  .collection('account_deletion_requests')
                  .doc(req['id'] as String)
                  .update({
                'status': 'approved',
                'reviewedBy': widget.officerName,
                'reviewedAt': FieldValue.serverTimestamp(),
              });
              await _notifyCitizen(
                req,
                title: 'Account Deletion Request Approved',
                message:
                    'Your account deletion request has been approved. Open Privacy & Security to choose whether to deactivate or permanently delete your account.',
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('web_request_approved'.tr()),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('web_approve_button'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectRequest(Map<String, dynamic> req) async {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('web_reject_deletion_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('web_citizen_label'.tr(args: ['${req['name'] ?? 'web_unknown'.tr()}'])),
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
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('web_provide_rejection_reason_snackbar'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              await FirebaseFirestore.instance
                  .collection('account_deletion_requests')
                  .doc(req['id'] as String)
                  .update({
                'status': 'rejected',
                'rejectionReason': reasonController.text.trim(),
                'reviewedBy': widget.officerName,
                'reviewedAt': FieldValue.serverTimestamp(),
              });
              await _notifyCitizen(
                req,
                title: 'Account Deletion Request Rejected',
                message:
                    'Your account deletion request was rejected: ${reasonController.text.trim()}',
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('web_request_rejected'.tr()),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('web_reject_button'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = selectedFilter == 'All'
        ? _requests
        : _requests.where((r) => (r['status'] as String? ?? '').toLowerCase() == selectedFilter.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('web_menu_account_deletion_requests'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'web_failed_load_requests'.tr(args: ['$_error']),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard('web_stat_total'.tr(), _requests.length.toString(), Colors.blue),
                      const SizedBox(width: 12),
                      _buildStatCard(
                          'pending'.tr(),
                          _requests.where((r) => r['status'] == 'pending').length.toString(),
                          Colors.orange),
                      const SizedBox(width: 12),
                      _buildStatCard(
                          'web_status_approved'.tr(),
                          _requests.where((r) => r['status'] == 'approved').length.toString(),
                          Colors.green),
                      const SizedBox(width: 12),
                      _buildStatCard(
                          'web_status_rejected'.tr(),
                          _requests.where((r) => r['status'] == 'rejected').length.toString(),
                          Colors.red),
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10)],
                      ),
                      child: filtered.isEmpty
                          ? Center(child: Text('web_no_requests_found'.tr()))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  columnSpacing: 16,
                                  dataRowHeight: 60,
                                  columns: [
                                    DataColumn(label: Text('web_citizen_name'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('web_col_nic'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('web_requested_col'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('web_reason_col'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('web_col_status'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('web_reviewed_by_col'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('web_col_actions'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                  ],
                                  rows: filtered.map((req) {
                                    final status = req['status'] as String? ?? 'pending';
                                    final statusColor = status == 'approved'
                                        ? Colors.green
                                        : (status == 'pending' ? Colors.orange : Colors.red);
                                    return DataRow(cells: [
                                      DataCell(Text(req['name'] as String? ?? 'web_unknown'.tr())),
                                      DataCell(Text(req['nic'] as String? ?? '—')),
                                      DataCell(Text(_formatTimestamp(req['requestedAt'] as Timestamp?))),
                                      DataCell(SizedBox(
                                        width: 160,
                                        child: Text(
                                          (req['reason'] as String?)?.isNotEmpty == true ? req['reason'] as String : '—',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(_statusLabel(status),
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                      DataCell(Text(req['reviewedBy'] as String? ?? '—')),
                                      DataCell(
                                        status == 'pending'
                                            ? Wrap(
                                                spacing: 4,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                                                    onPressed: () => _approveRequest(req),
                                                    tooltip: 'web_approve_tooltip'.tr(),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                                    onPressed: () => _rejectRequest(req),
                                                    tooltip: 'web_reject_tooltip'.tr(),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                ],
                                              )
                                            : (status == 'rejected'
                                                ? Text(
                                                    req['rejectionReason'] as String? ?? '',
                                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                    overflow: TextOverflow.ellipsis,
                                                  )
                                                : const Text('—')),
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
          boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 5)],
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
