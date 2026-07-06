import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    final snapshot = await FirebaseFirestore.instance
        .collection('account_deletion_requests')
        .get();
    final docs = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList()
      ..sort((a, b) {
        final aTime = a['requestedAt'] as Timestamp?;
        final bTime = b['requestedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
    if (!mounted) return;
    setState(() {
      _requests = docs;
      _loading = false;
    });
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _approveRequest(Map<String, dynamic> req) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve Deletion Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Citizen: ${req['name'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('NIC: ${req['nic'] ?? '—'}'),
            if ((req['reason'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Reason: ${req['reason']}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
              await _loadRequests();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request approved'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
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
        title: const Text('Reject Deletion Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Citizen: ${req['name'] ?? 'Unknown'}'),
            const SizedBox(height: 12),
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for rejection'),
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
              await _loadRequests();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request rejected'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
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
        title: const Text('Account Deletion Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard('Total', _requests.length.toString(), Colors.blue),
                      const SizedBox(width: 12),
                      _buildStatCard(
                          'Pending',
                          _requests.where((r) => r['status'] == 'pending').length.toString(),
                          Colors.orange),
                      const SizedBox(width: 12),
                      _buildStatCard(
                          'Approved',
                          _requests.where((r) => r['status'] == 'approved').length.toString(),
                          Colors.green),
                      const SizedBox(width: 12),
                      _buildStatCard(
                          'Rejected',
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
                        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10)],
                      ),
                      child: filtered.isEmpty
                          ? const Center(child: Text('No requests found'))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  columnSpacing: 16,
                                  dataRowHeight: 60,
                                  columns: const [
                                    DataColumn(label: Text('Citizen Name', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('NIC', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Requested', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Reviewed By', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                  ],
                                  rows: filtered.map((req) {
                                    final status = req['status'] as String? ?? 'pending';
                                    final statusColor = status == 'approved'
                                        ? Colors.green
                                        : (status == 'pending' ? Colors.orange : Colors.red);
                                    return DataRow(cells: [
                                      DataCell(Text(req['name'] as String? ?? 'Unknown')),
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
                                          child: Text(status[0].toUpperCase() + status.substring(1),
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
                                                    tooltip: 'Approve',
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                                    onPressed: () => _rejectRequest(req),
                                                    tooltip: 'Reject',
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
