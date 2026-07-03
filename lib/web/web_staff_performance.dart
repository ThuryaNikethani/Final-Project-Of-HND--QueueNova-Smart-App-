import 'package:flutter/material.dart';

class WebStaffPerformance extends StatefulWidget {
  const WebStaffPerformance({super.key});

  @override
  State<WebStaffPerformance> createState() => _WebStaffPerformanceState();
}

class _WebStaffPerformanceState extends State<WebStaffPerformance> {
  String selectedPeriod = 'This Week';
  final List<String> periods = ['Today', 'This Week', 'This Month', 'This Year'];

  final List<Map<String, dynamic>> staff = [
    {'name': 'Sarah Johnson', 'role': 'Queue Manager', 'completed': 156, 'avgTime': 4.2, 'satisfaction': 4.8, 'status': 'Online', 'avatar': 'SJ', 'target': 150},
    {'name': 'Michael Chen', 'role': 'Service Officer', 'completed': 142, 'avgTime': 5.1, 'satisfaction': 4.6, 'status': 'Online', 'avatar': 'MC', 'target': 140},
    {'name': 'Priya Sharma', 'role': 'Reception', 'completed': 98, 'avgTime': 2.8, 'satisfaction': 4.9, 'status': 'Online', 'avatar': 'PS', 'target': 100},
    {'name': 'David Kim', 'role': 'Service Officer', 'completed': 87, 'avgTime': 6.3, 'satisfaction': 4.2, 'status': 'Away', 'avatar': 'DK', 'target': 130},
    {'name': 'Lisa Wong', 'role': 'Queue Manager', 'completed': 76, 'avgTime': 3.9, 'satisfaction': 4.7, 'status': 'Online', 'avatar': 'LW', 'target': 120},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Performance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                const Icon(Icons.notifications_none, color: Colors.grey),
                const SizedBox(width: 16),
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF1A56DB),
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Admin', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('System Administrator', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
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
            // Period Selector & Summary Stats
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPeriod,
                      items: periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setState(() => selectedPeriod = v!),
                    ),
                  ),
                ),
                const Spacer(),
                _buildSummaryCard('Total Services', '559', '+12%', Icons.assignment, Colors.blue),
                const SizedBox(width: 16),
                _buildSummaryCard('Avg. Response', '4.2min', '-0.5', Icons.timer, Colors.green),
                const SizedBox(width: 16),
                _buildSummaryCard('Satisfaction', '4.7', '+0.3', Icons.star, Colors.orange),
                const SizedBox(width: 16),
                _buildSummaryCard('Completion Rate', '94%', '+2%', Icons.percent, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            // Staff Performance Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 30,
                    columns: const [
                      DataColumn(label: Text('Staff Member')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Completed')),
                      DataColumn(label: Text('Target')),
                      DataColumn(label: Text('Achievement')),
                      DataColumn(label: Text('Avg. Time')),
                      DataColumn(label: Text('Satisfaction')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Performance')),
                    ],
                    rows: staff.map((member) {
                      final achievement = (member['completed'] / member['target']).clamp(0.0, 1.0);
                      final performance = (member['completed'] / 200).clamp(0.0, 1.0);
                      return DataRow(cells: [
                        DataCell(Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF1A56DB).withOpacity(0.1),
                              child: Text(member['avatar'], style: const TextStyle(color: Color(0xFF1A56DB))),
                            ),
                            const SizedBox(width: 12),
                            Text(member['name']),
                          ],
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(member['role'], style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(Text('${member['completed']}')),
                        DataCell(Text('${member['target']}')),
                        DataCell(Text('${(achievement * 100).toInt()}%', style: TextStyle(
                          color: achievement >= 1.0 ? Colors.green : (achievement >= 0.8 ? Colors.orange : Colors.red),
                          fontWeight: FontWeight.bold,
                        ))),
                        DataCell(Text('${member['avgTime']} min')),
                        DataCell(Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('${member['satisfaction']}'),
                          ],
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: member['status'] == 'Online' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            member['status'],
                            style: TextStyle(color: member['status'] == 'Online' ? Colors.green : Colors.orange),
                          ),
                        )),
                        DataCell(SizedBox(
                          width: 100,
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: performance,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A56DB)),
                              ),
                              const SizedBox(height: 4),
                              Text('${(performance * 100).toInt()}%', style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        )),
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

  Widget _buildSummaryCard(String title, String value, String change, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(change, style: TextStyle(fontSize: 10, color: change.startsWith('+') ? Colors.green : Colors.red)),
            ],
          ),
        ],
      ),
    );
  }
}