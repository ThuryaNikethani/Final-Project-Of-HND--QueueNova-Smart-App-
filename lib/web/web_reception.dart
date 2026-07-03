import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class WebReception extends StatefulWidget {
  const WebReception({super.key});

  @override
  State<WebReception> createState() => _WebReceptionState();
}

class _WebReceptionState extends State<WebReception> {
  bool isScanning = false;
  String scannedData = '';
  int activeQueueCount = 24;
  int todayArrivals = 47;
  int walkInCount = 12;

  List<Map<String, dynamic>> todayAppointments = [
    {'token': 'A-024', 'citizen': 'K.N.T. Nikethani', 'service': 'Passport Renewal', 'time': '10:30 AM', 'status': 'Checked In', 'checkedIn': true, 'paymentStatus': 'paid', 'fee': 5000},
    {'token': 'A-025', 'citizen': 'Saman Perera', 'service': 'NIC Card', 'time': '11:00 AM', 'status': 'Not Checked In', 'checkedIn': false, 'paymentStatus': 'pending', 'fee': 500},
    {'token': 'A-026', 'citizen': 'Mala Kumari', 'service': 'Driving License', 'time': '11:30 AM', 'status': 'Not Checked In', 'checkedIn': false, 'paymentStatus': 'pending', 'fee': 3000},
    {'token': 'A-027', 'citizen': 'Ruwan Jaya', 'service': 'Birth Certificate', 'time': '12:00 PM', 'status': 'Checked In', 'checkedIn': true, 'paymentStatus': 'paid', 'fee': 200},
    {'token': 'A-028', 'citizen': 'Deepani Fernando', 'service': 'Police Clearance', 'time': '01:30 PM', 'status': 'Not Checked In', 'checkedIn': false, 'paymentStatus': 'pending', 'fee': 1000},
  ];

  List<Map<String, dynamic>> walkInQueue = [
    {'name': 'Nimal Silva', 'nic': '1978123456', 'service': 'NIC Card', 'time': '09:15 AM', 'token': 'W-001', 'status': 'Waiting'},
    {'name': 'Kamal Perera', 'nic': '1985123490', 'service': 'Passport', 'time': '09:45 AM', 'token': 'W-002', 'status': 'Waiting'},
    {'name': 'Sunil Jayawardena', 'nic': '1990123478', 'service': 'Driving License', 'time': '10:00 AM', 'token': 'W-003', 'status': 'Waiting'},
  ];

  void _processCheckIn(String qrData) {
    final appointment = todayAppointments.firstWhere(
      (apt) => apt['token'] == qrData || apt['citizen'].contains(qrData),
      orElse: () => {},
    );
    
    if (appointment.isNotEmpty && !appointment['checkedIn']) {
      setState(() {
        appointment['checkedIn'] = true;
        appointment['status'] = 'Checked In';
        todayArrivals++;
        activeQueueCount++;
        scannedData = 'Checked In: ${appointment['citizen']} (Token ${appointment['token']})';
      });
      
      final paymentStatus = appointment['paymentStatus'] == 'paid' ? 'Payment completed' : 'Payment pending at counter';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${appointment['citizen']} checked in successfully! Token ${appointment['token']} activated. $paymentStatus'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (appointment.isEmpty) {
      setState(() {
        scannedData = 'Invalid QR Code - No appointment found';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR Code'), backgroundColor: Colors.red),
      );
    } else {
      setState(() {
        scannedData = 'Already checked in: ${appointment['citizen']}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${appointment['citizen']} already checked in'), backgroundColor: Colors.orange),
      );
    }
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          scannedData = '';
        });
      }
    });
  }

  void _addWalkIn() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Walk-in Registration'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Citizen Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'NIC Number',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Service Type',
                  prefixIcon: Icon(Icons.assignment),
                ),
                items: const [
                  DropdownMenuItem(value: 'Passport Renewal', child: Text('Passport Renewal')),
                  DropdownMenuItem(value: 'NIC Card', child: Text('NIC Card')),
                  DropdownMenuItem(value: 'Driving License', child: Text('Driving License')),
                  DropdownMenuItem(value: 'Birth Certificate', child: Text('Birth Certificate')),
                ],
                onChanged: (value) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final newWalkIn = {
                  'name': 'New Citizen',
                  'nic': 'NEW123',
                  'service': 'General Service',
                  'time': DateTime.now().toString().substring(11, 16),
                  'token': 'W-${walkInQueue.length + 4}',
                  'status': 'Waiting',
                };
                walkInQueue.add(newWalkIn);
                walkInCount++;
                activeQueueCount++;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Walk-in registered successfully'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _callNextWalkIn() {
    if (walkInQueue.isNotEmpty) {
      final next = walkInQueue.removeAt(0);
      setState(() {
        activeQueueCount--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling ${next['name']} (Token ${next['token']}) to Counter 1'),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No walk-in customers in queue'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reception Dashboard'),
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
                    Text('Reception Officer', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Check-in', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatCard('Active Queue', '$activeQueueCount', Icons.queue, Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard("Today's Arrivals", '$todayArrivals', Icons.people, Colors.green),
                const SizedBox(width: 16),
                _buildStatCard('Walk-ins Today', '$walkInCount', Icons.person_add, Colors.orange),
                const SizedBox(width: 16),
                _buildStatCard('Appointments', '${todayAppointments.length}', Icons.calendar_today, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'QR Code Check-in',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 280,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF1A56DB), width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: isScanning
                                ? MobileScanner(
                                    onDetect: (capture) {
                                      final barcode = capture.barcodes.first;
                                      if (barcode.rawValue != null) {
                                        setState(() {
                                          isScanning = false;
                                        });
                                        _processCheckIn(barcode.rawValue!);
                                      }
                                    },
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.qr_code_scanner,
                                          size: 80,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          scannedData.isEmpty
                                              ? 'Ready to scan QR code'
                                              : scannedData,
                                          style: TextStyle(
                                            color: scannedData.contains('success') 
                                                ? Colors.green 
                                                : (scannedData.contains('Invalid') ? Colors.red : Colors.grey),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                isScanning = !isScanning;
                                if (!isScanning) {
                                  scannedData = '';
                                }
                              });
                            },
                            icon: Icon(isScanning ? Icons.stop : Icons.qr_code_scanner),
                            label: Text(isScanning ? 'Stop Scanning' : 'Start Scanning'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isScanning ? Colors.red : const Color(0xFF1A56DB),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Scan the QR code from citizen\'s mobile app to check them in and activate their queue token.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Today's Appointments",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${todayAppointments.where((a) => a['checkedIn']).length}/${todayAppointments.length} Checked In',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 250,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 30,
                                  columns: const [
                                    DataColumn(label: Text('Token')),
                                    DataColumn(label: Text('Citizen')),
                                    DataColumn(label: Text('Service')),
                                    DataColumn(label: Text('Time')),
                                    DataColumn(label: Text('Fee')),
                                    DataColumn(label: Text('Payment')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Action')),
                                  ],
                                  rows: todayAppointments.map((apt) {
                                    final isCheckedIn = apt['checkedIn'];
                                    final paymentColor = apt['paymentStatus'] == 'paid' ? Colors.green : Colors.orange;
                                    return DataRow(cells: [
                                      DataCell(Text(apt['token'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(apt['citizen'])),
                                      DataCell(Text(apt['service'])),
                                      DataCell(Text(apt['time'])),
                                      DataCell(Text('Rs. ${apt['fee']}')),
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: paymentColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              apt['paymentStatus'] == 'paid' ? Icons.check_circle : Icons.pending,
                                              size: 12,
                                              color: paymentColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              apt['paymentStatus'] == 'paid' ? 'Paid' : 'Pending',
                                              style: TextStyle(color: paymentColor, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      )),
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isCheckedIn ? Colors.green : Colors.orange).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          apt['status'],
                                          style: TextStyle(color: isCheckedIn ? Colors.green : Colors.orange),
                                        ),
                                      )),
                                      DataCell(
                                        isCheckedIn
                                            ? const Icon(Icons.check_circle, color: Colors.green)
                                            : ElevatedButton(
                                                onPressed: () {
                                                  if (apt['paymentStatus'] == 'pending') {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: const Text('Payment Required'),
                                                        content: Text('Payment of Rs. ${apt['fee']} is pending. Please collect payment at counter first.'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context),
                                                            child: const Text('OK'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  } else {
                                                    setState(() {
                                                      apt['checkedIn'] = true;
                                                      apt['status'] = 'Checked In';
                                                      todayArrivals++;
                                                      activeQueueCount++;
                                                    });
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('${apt['citizen']} checked in manually'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: apt['paymentStatus'] == 'pending' ? Colors.orange : const Color(0xFF1A56DB),
                                                ),
                                                child: Text(apt['paymentStatus'] == 'pending' ? 'Collect Payment' : 'Check In'),
                                              ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Walk-in Queue',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _addWalkIn,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Walk-in'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: _callNextWalkIn,
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Call Next'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1A56DB),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            walkInQueue.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: Text('No walk-in customers in queue'),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: walkInQueue.length,
                                    itemBuilder: (context, index) {
                                      final walkIn = walkInQueue[index];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1A56DB).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  walkIn['token'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1A56DB),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(walkIn['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  Text('${walkIn['service']} • ${walkIn['time']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                walkIn['status'],
                                                style: const TextStyle(color: Colors.orange),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}