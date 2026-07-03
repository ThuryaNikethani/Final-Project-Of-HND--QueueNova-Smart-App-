import 'package:flutter/material.dart';

class WebSystemHealth extends StatefulWidget {
  const WebSystemHealth({super.key});

  @override
  State<WebSystemHealth> createState() => _WebSystemHealthState();
}

class _WebSystemHealthState extends State<WebSystemHealth> {
  bool autoRefresh = false;
  String overallStatus = 'Operational';
  String uptime = '99.9%';
  
  List<Map<String, dynamic>> services = [
    {'name': 'Database Server', 'status': 'Healthy', 'uptime': '99.99%', 'response': '12ms', 'lastCheck': 'Just now'},
    {'name': 'API Gateway', 'status': 'Healthy', 'uptime': '99.95%', 'response': '45ms', 'lastCheck': 'Just now'},
    {'name': 'Notification Service', 'status': 'Healthy', 'uptime': '99.90%', 'response': '89ms', 'lastCheck': 'Just now'},
    {'name': 'QR Service', 'status': 'Healthy', 'uptime': '99.98%', 'response': '23ms', 'lastCheck': 'Just now'},
    {'name': 'File Storage', 'status': 'Degraded', 'uptime': '98.50%', 'response': '234ms', 'lastCheck': '2 min ago'},
  ];

  List<Map<String, dynamic>> systemMetrics = [
    {'metric': 'CPU Usage', 'value': '32%', 'status': 'Good', 'icon': Icons.memory, 'color': Colors.green},
    {'metric': 'Memory Usage', 'value': '2.4 GB / 8 GB', 'status': 'Good', 'icon': Icons.sd_storage, 'color': Colors.green},
    {'metric': 'Disk Space', 'value': '45% used', 'status': 'Warning', 'icon': Icons.storage, 'color': Colors.orange},
    {'metric': 'Active Sessions', 'value': '47', 'status': 'Good', 'icon': Icons.people, 'color': Colors.green},
    {'metric': 'API Requests/min', 'value': '234', 'status': 'Good', 'icon': Icons.api, 'color': Colors.green},
  ];

  List<Map<String, dynamic>> alerts = [
    {'type': 'Warning', 'title': 'File Storage Response Time High', 'description': 'Response time increased to 234ms', 'time': '2 min ago', 'color': Colors.orange},
    {'type': 'Success', 'title': 'Database Backup Completed', 'description': 'Full backup completed successfully', 'time': '1 hour ago', 'color': Colors.green},
    {'type': 'Info', 'title': 'New User Registered', 'description': 'Admin added new officer account', 'time': '3 hours ago', 'color': Colors.blue},
  ];

  void _refreshStatus() {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('System status refreshed'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Health Monitor'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Switch(
            value: autoRefresh,
            onChanged: (v) => setState(() => autoRefresh = v),
            activeColor: const Color(0xFF1A56DB),
          ),
          const Text('Auto Refresh', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 20),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Overall Health Status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 50),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('System Status: $overallStatus', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('All systems are running normally. $uptime uptime in last 30 days.', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Last 24h: 99.95%', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // System Metrics
            const Text('System Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: systemMetrics.map((metric) => _buildMetricCard(metric)).toList(),
            ),
            const SizedBox(height: 24),
            
            // Service Status
            const Text('Service Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 40,
                  columns: const [
                    DataColumn(label: Text('Service Name')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Uptime')),
                    DataColumn(label: Text('Response Time')),
                    DataColumn(label: Text('Last Check')),
                  ],
                  rows: services.map((service) {
                    final isHealthy = service['status'] == 'Healthy';
                    return DataRow(cells: [
                      DataCell(Text(service['name'], style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isHealthy ? Colors.green : Colors.orange).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(service['status'], style: TextStyle(color: isHealthy ? Colors.green : Colors.orange)),
                      )),
                      DataCell(Text(service['uptime'])),
                      DataCell(Text(service['response'])),
                      DataCell(Text(service['lastCheck'])),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Recent Alerts
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Recent Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ...alerts.map((alert) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: alert['color'],
                      child: Icon(
                        alert['type'] == 'Warning' ? Icons.warning : (alert['type'] == 'Success' ? Icons.check : Icons.info),
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    title: Text(alert['title']),
                    subtitle: Text(alert['description']),
                    trailing: Text(alert['time']),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(metric['icon'], size: 32, color: metric['color']),
          const SizedBox(height: 8),
          Text(metric['metric'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(metric['value'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: metric['color'])),
        ],
      ),
    );
  }
}