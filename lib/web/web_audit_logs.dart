import 'package:flutter/material.dart';

class WebAuditLogs extends StatefulWidget {
  const WebAuditLogs({super.key});

  @override
  State<WebAuditLogs> createState() => _WebAuditLogsState();
}

class _WebAuditLogsState extends State<WebAuditLogs> {
  String searchQuery = '';
  String selectedUser = 'All Users';
  String selectedAction = 'All Actions';

  final List<String> users = ['All Users', 'Admin', 'Queue Officer', 'Service Officer', 'Reception', 'Manager'];
  final List<String> actions = ['All Actions', 'Login', 'Logout', 'Create', 'Update', 'Delete', 'Approve', 'Reject', 'Check-in', 'Call Token'];

  List<Map<String, dynamic>> auditLogs = [
    {'time': '2026-05-21 09:15:23', 'user': 'admin@queuenova.gov.lk', 'userRole': 'Admin', 'action': 'Login', 'ip': '192.168.1.100', 'status': 'Success', 'details': 'Logged in successfully'},
    {'time': '2026-05-21 08:45:12', 'user': 'queue@queuenova.gov.lk', 'userRole': 'Queue Officer', 'action': 'Call Token', 'ip': '192.168.1.101', 'status': 'Success', 'details': 'Called token A-025'},
    {'time': '2026-05-21 08:30:05', 'user': 'admin@queuenova.gov.lk', 'userRole': 'Admin', 'action': 'Create', 'ip': '192.168.1.100', 'status': 'Success', 'details': 'Added new officer: Sarah Johnson'},
    {'time': '2026-05-20 17:30:45', 'user': 'service@queuenova.gov.lk', 'userRole': 'Service Officer', 'action': 'Approve', 'ip': '192.168.1.102', 'status': 'Success', 'details': 'Approved application REQ001'},
    {'time': '2026-05-20 14:20:33', 'user': 'unknown', 'userRole': 'Unknown', 'action': 'Login', 'ip': '203.0.113.45', 'status': 'Failed', 'details': 'Invalid password attempt'},
    {'time': '2026-05-20 10:05:22', 'user': 'reception@queuenova.gov.lk', 'userRole': 'Reception', 'action': 'Check-in', 'ip': '192.168.1.103', 'status': 'Success', 'details': 'Checked in citizen K.N.T. Nikethani'},
    {'time': '2026-05-20 09:15:44', 'user': 'admin@queuenova.gov.lk', 'userRole': 'Admin', 'action': 'Update', 'ip': '192.168.1.100', 'status': 'Success', 'details': 'Updated queue settings'},
    {'time': '2026-05-19 16:30:12', 'user': 'manager@queuenova.gov.lk', 'userRole': 'Manager', 'action': 'Export', 'ip': '192.168.1.104', 'status': 'Success', 'details': 'Exported monthly report'},
  ];

  List<Map<String, dynamic>> get filteredLogs {
    return auditLogs.where((log) {
      final matchesSearch = searchQuery.isEmpty || 
          log['user'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          log['action'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          log['details'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      final matchesUser = selectedUser == 'All Users' || log['userRole'] == selectedUser;
      final matchesAction = selectedAction == 'All Actions' || log['action'] == selectedAction;
      return matchesSearch && matchesUser && matchesAction;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      selectedUser = 'All Users';
      selectedAction = 'All Actions';
    });
  }

  void _exportLogs() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting logs...'), backgroundColor: Colors.blue),
    );
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'Login': return Colors.blue;
      case 'Logout': return Colors.grey;
      case 'Create': return Colors.green;
      case 'Delete': return Colors.red;
      case 'Approve': return Colors.green;
      case 'Reject': return Colors.red;
      case 'Check-in': return Colors.orange;
      case 'Update': return Colors.purple;
      case 'Call Token': return const Color(0xFF1A56DB);
      default: return const Color(0xFF1A56DB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          onChanged: (v) => setState(() => searchQuery = v),
                          decoration: const InputDecoration(
                            hintText: 'Search logs...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedUser,
                          decoration: const InputDecoration(
                            labelText: 'User Role',
                            border: OutlineInputBorder(),
                          ),
                          items: users.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) => setState(() => selectedUser = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedAction,
                          decoration: const InputDecoration(
                            labelText: 'Action Type',
                            border: OutlineInputBorder(),
                          ),
                          items: actions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                          onChanged: (v) => setState(() => selectedAction = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Total Logs: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${filtered.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56DB))),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Filters'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _exportLogs,
                        icon: const Icon(Icons.download),
                        label: const Text('Export Logs'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Audit Logs Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 30,
                    columns: const [
                      DataColumn(label: Text('Timestamp')),
                      DataColumn(label: Text('User')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('IP Address')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Details')),
                    ],
                    rows: filtered.map((log) {
                      final isSuccess = log['status'] == 'Success';
                      return DataRow(cells: [
                        DataCell(Text(log['time'])),
                        DataCell(Text(log['user'])),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(log['userRole'], style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getActionColor(log['action']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(log['action'], style: TextStyle(fontSize: 11, color: _getActionColor(log['action']))),
                        )),
                        DataCell(Text(log['ip'])),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(log['status'], style: TextStyle(color: isSuccess ? Colors.green : Colors.red)),
                        )),
                        DataCell(Text(log['details'], style: const TextStyle(fontSize: 12))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}