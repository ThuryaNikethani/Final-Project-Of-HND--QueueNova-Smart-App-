import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

/// Live audit trail of every SMS/push send attempt (written by
/// [WebAccountDeletionRequests] and any future notification flow), so staff
/// can confirm whether a citizen actually received a message rather than
/// just seeing it was queued.
class WebNotificationDeliveryLog extends StatefulWidget {
  const WebNotificationDeliveryLog({super.key});

  @override
  State<WebNotificationDeliveryLog> createState() => _WebNotificationDeliveryLogState();
}

class _WebNotificationDeliveryLogState extends State<WebNotificationDeliveryLog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];
  StreamSubscription<QuerySnapshot>? _subscription;

  String _searchQuery = '';
  String _channelFilter = 'All';
  String _statusFilter = 'All';

  final List<String> _channels = ['All', 'sms', 'push'];
  final List<String> _statuses = ['All', 'Success', 'Failed'];

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collection('notification_delivery_logs')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _logs = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
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

  List<Map<String, dynamic>> get _filtered {
    return _logs.where((log) {
      final matchesChannel = _channelFilter == 'All' || log['channel'] == _channelFilter;
      final success = log['success'] as bool? ?? false;
      final matchesStatus = _statusFilter == 'All' ||
          (_statusFilter == 'Success' && success) ||
          (_statusFilter == 'Failed' && !success);
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          (log['recipient'] as String? ?? '').toLowerCase().contains(q) ||
          (log['uid'] as String? ?? '').toLowerCase().contains(q) ||
          (log['title'] as String? ?? '').toLowerCase().contains(q);
      return matchesChannel && matchesStatus && matchesSearch;
    }).toList();
  }

  String _statusFilterLabel(String status) {
    switch (status) {
      case 'All': return 'web_status_all'.tr();
      case 'Success': return 'web_status_success'.tr();
      case 'Failed': return 'web_status_failed'.tr();
      default: return status;
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final successCount = _logs.where((l) => l['success'] == true).length;
    final failedCount = _logs.length - successCount;
    final smsCount = _logs.where((l) => l['channel'] == 'sms').length;
    final pushCount = _logs.where((l) => l['channel'] == 'push').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('web_menu_notification_delivery_log'.tr()),
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
                      'web_failed_load_delivery_log'.tr(args: ['$_error']),
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
                          _buildStatCard('web_stat_total'.tr(), _logs.length.toString(), Colors.blue),
                          const SizedBox(width: 12),
                          _buildStatCard('web_channel_sms'.tr(), smsCount.toString(), Colors.purple),
                          const SizedBox(width: 12),
                          _buildStatCard('web_channel_push'.tr(), pushCount.toString(), Colors.teal),
                          const SizedBox(width: 12),
                          _buildStatCard('web_delivered_status'.tr(), successCount.toString(), Colors.green),
                          const SizedBox(width: 12),
                          _buildStatCard('web_status_failed'.tr(), failedCount.toString(), Colors.red),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'web_search_delivery_log_hint'.tr(),
                                  prefixIcon: const Icon(Icons.search),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _channelFilter,
                                decoration: InputDecoration(labelText: 'web_channel_label'.tr(), border: const OutlineInputBorder()),
                                items: _channels
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'web_status_all'.tr() : c.toUpperCase())))
                                    .toList(),
                                onChanged: (v) => setState(() => _channelFilter = v!),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _statusFilter,
                                decoration: InputDecoration(labelText: 'web_col_status'.tr(), border: const OutlineInputBorder()),
                                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(_statusFilterLabel(s)))).toList(),
                                onChanged: (v) => setState(() => _statusFilter = v!),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10)],
                          ),
                          child: filtered.isEmpty
                              ? Center(child: Text('web_no_delivery_attempts'.tr()))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: DataTable(
                                      columnSpacing: 20,
                                      columns: [
                                        DataColumn(label: Text('web_col_timestamp'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('web_channel_label'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('web_recipient_col'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('web_title_col'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('web_col_status'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('web_error_col'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                      ],
                                      rows: filtered.map((log) {
                                        final success = log['success'] as bool? ?? false;
                                        final channel = log['channel'] as String? ?? '—';
                                        return DataRow(cells: [
                                          DataCell(Text(_formatTimestamp(log['createdAt'] as Timestamp?))),
                                          DataCell(Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (channel == 'sms' ? Colors.purple : Colors.teal).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(channel.toUpperCase(),
                                                style: TextStyle(color: channel == 'sms' ? Colors.purple : Colors.teal, fontSize: 11)),
                                          )),
                                          DataCell(Text(log['recipient'] as String? ?? '—')),
                                          DataCell(SizedBox(
                                            width: 200,
                                            child: Text(log['title'] as String? ?? '—', overflow: TextOverflow.ellipsis),
                                          )),
                                          DataCell(Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (success ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(success ? 'web_delivered_status'.tr() : 'web_status_failed'.tr(),
                                                style: TextStyle(color: success ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                                          )),
                                          DataCell(SizedBox(
                                            width: 220,
                                            child: Text(
                                              success ? '—' : (log['error'] as String? ?? 'web_unknown_error'.tr()),
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
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
