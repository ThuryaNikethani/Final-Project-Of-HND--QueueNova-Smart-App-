import 'package:flutter/material.dart';

class WebAppointments extends StatefulWidget {
  const WebAppointments({super.key});

  @override
  State<WebAppointments> createState() => _WebAppointmentsState();
}

class _WebAppointmentsState extends State<WebAppointments> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled'];

  List<Map<String, dynamic>> appointments = [
    {
      'id': 'APT001',
      'citizen': 'K.N.T. Nikethani',
      'nic': '200486403960',
      'service': 'Passport Renewal',
      'office': 'Divisional Secretariat - Colombo',
      'date': '25 May 2026',
      'time': '10:30 AM',
      'status': 'Confirmed',
      'token': 'A-024',
      'fee': 5000,
      'paymentStatus': 'paid',
      'paymentMethod': 'Pay Online',
    },
    {
      'id': 'APT002',
      'citizen': 'Saman Perera',
      'nic': '855420159V',
      'service': 'NIC Card',
      'office': 'Department of Registration',
      'date': '28 May 2026',
      'time': '02:00 PM',
      'status': 'Confirmed',
      'token': 'B-015',
      'fee': 500,
      'paymentStatus': 'pending',
      'paymentMethod': 'Pay at Counter',
    },
    {
      'id': 'APT003',
      'citizen': 'Mala Kumari',
      'nic': '925230080V',
      'service': 'Driving License',
      'office': 'RMV - Werahera',
      'date': '30 May 2026',
      'time': '09:00 AM',
      'status': 'Pending',
      'token': 'C-089',
      'fee': 3000,
      'paymentStatus': 'pending',
      'paymentMethod': 'Pay Online',
    },
    {
      'id': 'APT004',
      'citizen': 'Ruwan Jaya',
      'nic': '1987456321',
      'service': 'Birth Certificate',
      'office': 'Divisional Secretariat - Kandy',
      'date': '01 Jun 2026',
      'time': '11:00 AM',
      'status': 'Confirmed',
      'token': 'D-032',
      'fee': 200,
      'paymentStatus': 'paid',
      'paymentMethod': 'Pay at Counter',
    },
    {
      'id': 'APT005',
      'citizen': 'Nimal Silva',
      'nic': '1978123456',
      'service': 'Police Clearance',
      'office': 'Police Headquarters',
      'date': '15 May 2026',
      'time': '01:30 PM',
      'status': 'Completed',
      'token': 'E-056',
      'fee': 1000,
      'paymentStatus': 'paid',
      'paymentMethod': 'Pay Online',
    },
  ];

  List<Map<String, dynamic>> get filteredAppointments {
    if (selectedFilter == 'All') return appointments;
    return appointments.where((a) => a['status'] == selectedFilter).toList();
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Confirmed': return Colors.green;
      case 'Completed': return Colors.blue;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color getPaymentColor(String paymentStatus) {
    return paymentStatus == 'paid' ? Colors.green : Colors.orange;
  }

  void _confirmPayment(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Citizen: ${appointment['citizen']}'),
            Text('Service: ${appointment['service']}'),
            Text('Amount: Rs. ${appointment['fee']}'),
            const SizedBox(height: 16),
            const Text('Confirm that payment has been received at the counter?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                appointment['paymentStatus'] = 'paid';
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment confirmed'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Appointment Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow('Appointment ID', appointment['id']),
              const SizedBox(height: 12),
              _buildDetailRow('Citizen Name', appointment['citizen']),
              const SizedBox(height: 12),
              _buildDetailRow('NIC Number', appointment['nic']),
              const SizedBox(height: 12),
              _buildDetailRow('Service', appointment['service']),
              const SizedBox(height: 12),
              _buildDetailRow('Office', appointment['office']),
              const SizedBox(height: 12),
              _buildDetailRow('Date', appointment['date']),
              const SizedBox(height: 12),
              _buildDetailRow('Time', appointment['time']),
              const SizedBox(height: 12),
              _buildDetailRow('Token', appointment['token']),
              const SizedBox(height: 12),
              _buildDetailRow('Fee', 'Rs. ${appointment['fee']}'),
              const SizedBox(height: 12),
              _buildPaymentRow('Payment Status', appointment['paymentStatus'], appointment['paymentMethod']),
              const SizedBox(height: 12),
              _buildDetailRow('Status', appointment['status'], isStatus: true, statusColor: getStatusColor(appointment['status'])),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (appointment['paymentStatus'] == 'pending')
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmPayment(appointment);
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('Confirm Payment'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  if (appointment['status'] == 'Pending')
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          appointment['status'] = 'Confirmed';
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Appointment confirmed'), backgroundColor: Colors.green),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false, Color? statusColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: isStatus
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
                  ),
                )
              : Text(value),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, String paymentStatus, String paymentMethod) {
    final paymentColor = getPaymentColor(paymentStatus);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 120,
          child: Text(
            'Payment',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: paymentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      paymentStatus == 'paid' ? 'Paid' : 'Pending',
                      style: TextStyle(
                        color: paymentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'via $paymentMethod',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredAppointments;
    final pendingPayments = appointments.where((a) => a['paymentStatus'] == 'pending').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (pendingPayments > 0)
            Container(
              margin: const EdgeInsets.only(right: 20),
              child: Stack(
                children: [
                  const Icon(Icons.payment, color: Colors.grey),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$pendingPayments',
                        style: const TextStyle(color: Colors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                    Text('Administrator', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
            // Stats Cards
            Row(
              children: [
                _buildStatCard('Total Appointments', appointments.length.toString(), Icons.calendar_today, Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard('Pending', appointments.where((a) => a['status'] == 'Pending').length.toString(), Icons.pending, Colors.orange),
                const SizedBox(width: 16),
                _buildStatCard('Confirmed', appointments.where((a) => a['status'] == 'Confirmed').length.toString(), Icons.check_circle, Colors.green),
                const SizedBox(width: 16),
                _buildStatCard('Pending Payments', pendingPayments.toString(), Icons.payment, Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            // Filter Chips
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
            // Appointments Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 30,
                    columns: const [
                      DataColumn(label: Text('Appointment ID')),
                      DataColumn(label: Text('Citizen')),
                      DataColumn(label: Text('Service')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('Fee')),
                      DataColumn(label: Text('Payment')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: filtered.map((apt) {
                      final statusColor = getStatusColor(apt['status']);
                      final paymentColor = getPaymentColor(apt['paymentStatus']);
                      return DataRow(cells: [
                        DataCell(Text(apt['id'], style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(apt['citizen'])),
                        DataCell(Text(apt['service'])),
                        DataCell(Text(apt['date'])),
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
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(apt['status'], style: TextStyle(color: statusColor)),
                        )),
                        DataCell(Row(
                          children: [
                            if (apt['paymentStatus'] == 'pending')
                              IconButton(
                                icon: const Icon(Icons.payment, color: Colors.green),
                                onPressed: () => _confirmPayment(apt),
                                tooltip: 'Confirm Payment',
                              ),
                            IconButton(
                              icon: const Icon(Icons.visibility, color: Color(0xFF1A56DB)),
                              onPressed: () => _showAppointmentDetails(apt),
                              tooltip: 'View Details',
                            ),
                          ],
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