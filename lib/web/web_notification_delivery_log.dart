import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        title: const Text('Notification Delivery Log'),
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
                      'Failed to load delivery log:\n$_error',
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
                          _buildStatCard('Total', _logs.length.toString(), Colors.blue),
                          const SizedBox(width: 12),
                          _buildStatCard('SMS', smsCount.toString(), Colors.purple),
                          const SizedBox(width: 12),
                          _buildStatCard('Push', pushCount.toString(), Colors.teal),
                          const SizedBox(width: 12),
                          _buildStatCard('Delivered', successCount.toString(), Colors.green),
                          const SizedBox(width: 12),
                          _buildStatCard('Failed', failedCount.toString(), Colors.red),
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
                                decoration: const InputDecoration(
                                  hintText: 'Search by recipient, citizen uid, or title...',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _channelFilter,
                                decoration: const InputDecoration(labelText: 'Channel', border: OutlineInputBorder()),
                                items: _channels
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? c : c.toUpperCase())))
                                    .toList(),
                                onChanged: (v) => setState(() => _channelFilter = v!),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _statusFilter,
                                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
                              ? const Center(child: Text('No delivery attempts found'))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: DataTable(
                                      columnSpacing: 20,
                                      columns: const [
                                        DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('Channel', style: TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('Recipient', style: TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                        DataColumn(label: Text('Error', style: TextStyle(fontWeight: FontWeight.w600))),
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
                                            child: Text(success ? 'Delivered' : 'Failed',
                                                style: TextStyle(color: success ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                                          )),
                                          DataCell(SizedBox(
                                            width: 220,
                                            child: Text(
                                              success ? '—' : (log['error'] as String? ?? 'Unknown error'),
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
