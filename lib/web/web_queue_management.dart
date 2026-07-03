import 'package:flutter/material.dart';
import 'web_components/modern_ui_components.dart';
import 'web_api_service.dart';

class WebQueueManagement extends StatefulWidget {
  const WebQueueManagement({super.key});

  @override
  State<WebQueueManagement> createState() => _WebQueueManagementState();
}

class _WebQueueManagementState extends State<WebQueueManagement> {
  int currentServing = 24;
  int totalInQueue = 12;
  int avgWaitTime = 25;
  String crowdLevel = 'Medium';
  String selectedOffice = 'Divisional Secretariat - Colombo';

  final List<String> offices = [
    'Divisional Secretariat - Colombo',
    'RMV - Werahera',
    'Passport Office - Battaramulla',
  ];

  List<Map<String, dynamic>> queueList = [
    {
      'token': 'A-025',
      'citizen': 'K.N.T. Nikethani',
      'service': 'Passport Renewal',
      'status': 'waiting',
      'waitTime': '25 min',
      'isPriority': false,
      'counter': 1,
      'paymentStatus': 'paid',
      'fee': 5000,
    },
    {
      'token': 'A-026',
      'citizen': 'Saman Perera',
      'service': 'NIC Card',
      'status': 'waiting',
      'waitTime': '30 min',
      'isPriority': false,
      'counter': 1,
      'paymentStatus': 'paid',
      'fee': 500,
    },
    {
      'token': 'A-027',
      'citizen': 'Mala Kumari',
      'service': 'Driving License',
      'status': 'waiting',
      'waitTime': '35 min',
      'isPriority': true,
      'counter': 2,
      'paymentStatus': 'pending',
      'fee': 3000,
    },
    {
      'token': 'A-028',
      'citizen': 'Ruwan Jaya',
      'service': 'Birth Certificate',
      'status': 'waiting',
      'waitTime': '40 min',
      'isPriority': false,
      'counter': 1,
      'paymentStatus': 'paid',
      'fee': 200,
    },
    {
      'token': 'A-029',
      'citizen': 'Deepani Fernando',
      'service': 'NIC Card',
      'status': 'waiting',
      'waitTime': '45 min',
      'isPriority': false,
      'counter': 1,
      'paymentStatus': 'pending',
      'fee': 500,
    },
  ];

  List<Map<String, dynamic>> emergencyQueue = [
    {
      'token': 'E-001',
      'citizen': 'Senior Citizen',
      'service': 'Medical Emergency',
      'status': 'priority',
      'waitTime': '5 min',
      'paymentStatus': 'paid',
    },
    {
      'token': 'E-002',
      'citizen': 'Pregnant Woman',
      'service': 'Document Urgent',
      'status': 'priority',
      'waitTime': '10 min',
      'paymentStatus': 'pending',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadQueueFromApi();
  }

  Future<void> _loadQueueFromApi() async {
    final rows = await WebApiService.getQueue(selectedOffice);
    final emergency = await WebApiService.getEmergencyQueue(selectedOffice);
    if (!mounted) return;
    if (rows.isNotEmpty) {
      setState(() {
        queueList = rows.map((r) => {
          'token': r['token'] ?? '',
          'citizen': r['citizen_name'] ?? '',
          'service': r['service'] ?? '',
          'status': r['status'] ?? 'waiting',
          'waitTime': r['wait_time'] ?? '-- min',
          'isPriority': r['is_priority'] == true || r['is_priority'] == 1,
          'counter': r['counter'] ?? 1,
          'paymentStatus': r['payment_status'] ?? 'pending',
          'fee': (r['fee'] ?? 0).toDouble(),
          'id': r['id'],
        }).toList();
        totalInQueue = queueList.length;
      });
    }
    if (emergency.isNotEmpty) {
      setState(() {
        emergencyQueue = emergency.map((e) => {
          'token': e['token'] ?? '',
          'citizen': e['citizen_name'] ?? '',
          'service': e['reason'] ?? '',
          'status': e['status'] ?? 'priority',
          'waitTime': '-- min',
          'paymentStatus': e['payment_status'] ?? 'paid',
          'id': e['id'],
        }).toList();
      });
    }
  }

  Color getPaymentColor(String paymentStatus) {
    return paymentStatus == 'paid' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
  }

  void _callNextToken() {
    if (queueList.isEmpty) return;
    final nextToken = queueList.first;

    if (nextToken['paymentStatus'] == 'pending') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Required'),
          content: Text('Payment of Rs. ${nextToken['fee']} is pending for ${nextToken['citizen']}. Please collect payment first.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }

    // Optimistic UI
    setState(() {
      currentServing = int.tryParse(nextToken['token'].toString().split('-').last) ?? currentServing;
      queueList.removeAt(0);
      totalInQueue--;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Token ${nextToken['token']} called. Please proceed to Counter ${nextToken['counter']}.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Persist to backend
    WebApiService.callNext(selectedOffice, 'Queue Officer');
  }

  void _completeService(Map<String, dynamic> token) {
    // Optimistic UI
    setState(() {
      queueList.remove(token);
      totalInQueue--;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service completed. Token removed from queue.'), backgroundColor: Colors.blue),
    );

    // Persist to backend
    WebApiService.completeService(token['token'].toString(), 'Service Officer');
  }

  void _sendNotification(Map<String, dynamic> token) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notification sent to ${token['citizen']} for token ${token['token']}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _reassignCounter(Map<String, dynamic> token) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reassign Counter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Token: ${token['token']}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: token['counter'] as int? ?? 1,
              decoration: const InputDecoration(labelText: 'Select Counter'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Counter 1')),
                DropdownMenuItem(value: 2, child: Text('Counter 2')),
                DropdownMenuItem(value: 3, child: Text('Counter 3')),
                DropdownMenuItem(value: 4, child: Text('Counter 4')),
              ],
              onChanged: (value) {
                final newCounter = value ?? 1;
                setState(() => token['counter'] = newCounter);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Token ${token['token']} reassigned to Counter $newCounter'), backgroundColor: Colors.green),
                );
                // Persist to backend
                WebApiService.reassignCounter(token['token'].toString(), newCounter, 'Queue Officer');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _processEmergencyQueue() {
    if (emergencyQueue.isEmpty) return;
    final emergencyToken = emergencyQueue.first;

    if (emergencyToken['paymentStatus'] == 'pending') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Required'),
          content: const Text('Payment is pending for this emergency request. Please collect payment first.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Token: ${emergencyToken['token']}'),
            Text('Citizen: ${emergencyToken['citizen']}'),
            Text('Reason: ${emergencyToken['service']}'),
            const SizedBox(height: 16),
            const Text('This is a priority request. Process immediately?'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          ElevatedButton(
            onPressed: () {
              final tokenStr = emergencyToken['token'].toString();
              setState(() {
                emergencyQueue.removeAt(0);
                currentServing = int.tryParse(tokenStr.split('-').last) ?? currentServing;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Emergency token called immediately!'), backgroundColor: Colors.red),
              );
              // Persist to backend
              WebApiService.processEmergency(tokenStr, 'Queue Officer');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Process Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Queue Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ModernBackground(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              ModernPageHeader(
                title: 'Queue Management',
                subtitle: 'Monitor and manage service queues in real-time',
                icon: Icons.queue,
                actions: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                        SizedBox(width: 6),
                        Text('System Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stats Row - Clean stat cards without overflow
              SizedBox(
                height: 100,
                child: Row(
                  children: [
                    _buildStatCard('Currently Serving', 'A-$currentServing', Icons.person_outline, const Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    _buildStatCard('Total in Queue', '$totalInQueue', Icons.queue, const Color(0xFF1A56DB)),
                    const SizedBox(width: 12),
                    _buildStatCard('Avg. Wait Time', '$avgWaitTime min', Icons.timer_outlined, const Color(0xFFF59E0B)),
                    const SizedBox(width: 12),
                    _buildStatCard('Crowd Level', crowdLevel, Icons.people_outline, _getCrowdColor()),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Office Selector and Actions
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          onChanged: (value) => setState(() => selectedOffice = value!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: _callNextToken,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Call Next'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (emergencyQueue.isNotEmpty)
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: _processEmergencyQueue,
                        icon: const Icon(Icons.warning_rounded, size: 18),
                        label: Text('Emergency (${emergencyQueue.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Emergency Queue Alert
              if (emergencyQueue.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Text(
                        '${emergencyQueue.length} urgent request(s) requiring immediate attention',
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (emergencyQueue.isNotEmpty) const SizedBox(height: 12),

              // Queue List Header
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Text(
                      'Current Queue',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56DB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${queueList.length} waiting', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A56DB))),
                    ),
                  ],
                ),
              ),

              // Queue List Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 14,
                        dataRowHeight: 48,
                        headingRowHeight: 40,
                        columns: const [
                          DataColumn(label: Text('Token', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('Citizen', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('Service', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('Wait Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('Counter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                        ],
                        rows: queueList.map((item) {
                          final paymentColor = getPaymentColor(item['paymentStatus']);
                          return DataRow(
                            color: MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.hovered)) {
                                  return const Color(0xFF1A56DB).withOpacity(0.05);
                                }
                                return null;
                              },
                            ),
                            cells: [
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A56DB).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(item['token'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF1A56DB))),
                                ),
                              ),
                              DataCell(Text(item['citizen'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11))),
                              DataCell(Text(item['service'], style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Colors.grey.shade700))),
                              DataCell(Text(item['waitTime'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: paymentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item['paymentStatus'] == 'paid' ? Icons.check_circle : Icons.pending,
                                        size: 11,
                                        color: paymentColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        item['paymentStatus'] == 'paid' ? 'Paid' : 'Pending',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: paymentColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item['isPriority'] ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item['isPriority'] ? 'Yes' : 'No',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                      color: item['isPriority'] ? Colors.red : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('C${item['counter']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF7C3AED))),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'Send Notification',
                                      child: IconButton(
                                        icon: const Icon(Icons.notifications_outlined),
                                        onPressed: () => _sendNotification(item),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.orange.withOpacity(0.1),
                                          foregroundColor: Colors.orange,
                                        ),
                                        iconSize: 14,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Reassign Counter',
                                      child: IconButton(
                                        icon: const Icon(Icons.swap_horiz_rounded),
                                        onPressed: () => _reassignCounter(item),
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFF1A56DB).withOpacity(0.1),
                                          foregroundColor: const Color(0xFF1A56DB),
                                        ),
                                        iconSize: 14,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Complete Service',
                                      child: IconButton(
                                        icon: const Icon(Icons.check_circle_outline),
                                        onPressed: () => _completeService(item),
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                                          foregroundColor: const Color(0xFF10B981),
                                        ),
                                        iconSize: 14,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCrowdColor() {
    switch (crowdLevel) {
      case 'Low':
        return const Color(0xFF10B981);
      case 'Medium':
        return const Color(0xFFF59E0B);
      case 'High':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }
}