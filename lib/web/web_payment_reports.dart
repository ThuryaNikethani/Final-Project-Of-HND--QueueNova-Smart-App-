import 'package:flutter/material.dart';
import 'dart:html' as html;

class WebPaymentReports extends StatefulWidget {
  const WebPaymentReports({super.key});

  @override
  State<WebPaymentReports> createState() => _WebPaymentReportsState();
}

class _WebPaymentReportsState extends State<WebPaymentReports> {
  String selectedPeriod = 'This Month';
  final List<String> periods = ['Today', 'This Week', 'This Month', 'This Year'];

  int totalCollections = 12500;
  int pendingPayments = 4500;
  int completedPayments = 8000;
  double collectionRate = 64.0;

  List<Map<String, dynamic>> transactions = [
    {'id': 'TXN001', 'citizen': 'K.N.T. Nikethani', 'service': 'Passport Renewal', 'amount': 5000, 'date': '2026-05-25', 'status': 'paid', 'method': 'Pay Online'},
    {'id': 'TXN002', 'citizen': 'Saman Perera', 'service': 'NIC Card', 'amount': 500, 'date': '2026-05-24', 'status': 'paid', 'method': 'Pay at Counter'},
    {'id': 'TXN003', 'citizen': 'Mala Kumari', 'service': 'Driving License', 'amount': 3000, 'date': '2026-05-23', 'status': 'pending', 'method': 'Pay Online'},
    {'id': 'TXN004', 'citizen': 'Ruwan Jaya', 'service': 'Birth Certificate', 'amount': 200, 'date': '2026-05-22', 'status': 'paid', 'method': 'Pay at Counter'},
    {'id': 'TXN005', 'citizen': 'Nimal Silva', 'service': 'Police Clearance', 'amount': 1000, 'date': '2026-05-21', 'status': 'pending', 'method': 'Pay Online'},
    {'id': 'TXN006', 'citizen': 'Kamal Perera', 'service': 'Passport Renewal', 'amount': 5000, 'date': '2026-05-20', 'status': 'paid', 'method': 'Pay Online'},
    {'id': 'TXN007', 'citizen': 'Sunil Jaya', 'service': 'Driving License', 'amount': 3000, 'date': '2026-05-19', 'status': 'paid', 'method': 'Pay at Counter'},
  ];

  List<Map<String, dynamic>> get filteredTransactions {
    final now = DateTime.now();
    if (selectedPeriod == 'Today') {
      return transactions.where((t) => t['date'] == now.toString().substring(0, 10)).toList();
    } else if (selectedPeriod == 'This Week') {
      return transactions;
    } else if (selectedPeriod == 'This Month') {
      return transactions;
    } else {
      return transactions;
    }
  }

  void _exportReport() {
    // Build CSV content
    final filtered = filteredTransactions;
    final total = filtered.fold<double>(0, (sum, t) => sum + (t['amount'] as int));
    final pending = filtered.where((t) => t['status'] == 'pending').fold<double>(0, (sum, t) => sum + (t['amount'] as int));
    final paid = filtered.where((t) => t['status'] == 'paid').fold<double>(0, (sum, t) => sum + (t['amount'] as int));
    final rate = total > 0 ? (paid / total * 100).toStringAsFixed(1) : '0';
    
    String csv = "PAYMENT REPORT\n";
    csv += "Generated: ${DateTime.now()}\n";
    csv += "Period: $selectedPeriod\n\n";
    
    csv += "KPI SUMMARY\n";
    csv += "Total Collections,Rs. $total\n";
    csv += "Pending Payments,Rs. $pending\n";
    csv += "Completed Payments,Rs. $paid\n";
    csv += "Collection Rate,$rate%\n\n";
    
    csv += "TRANSACTION HISTORY\n";
    csv += "Transaction ID,Citizen,Service,Amount (Rs.),Date,Method,Status\n";
    for (var tx in filtered) {
      csv += "${tx['id']},${tx['citizen']},${tx['service']},${tx['amount']},${tx['date']},${tx['method']},${tx['status']}\n";
    }
    
    // Download file
    final blob = html.Blob([csv], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'payment_report_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report exported successfully!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredTransactions;
    final total = filtered.fold<double>(0, (sum, t) => sum + (t['amount'] as int));
    final pending = filtered.where((t) => t['status'] == 'pending').fold<double>(0, (sum, t) => sum + (t['amount'] as int));
    final paid = filtered.where((t) => t['status'] == 'paid').fold<double>(0, (sum, t) => sum + (t['amount'] as int));
    final rate = total > 0 ? (paid / total * 100).toStringAsFixed(1) : '0';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Payment Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
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
                    Text('Manager', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Department Manager', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(  // ← FIX: Added SingleChildScrollView to prevent overflow
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
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
                ElevatedButton.icon(
                  onPressed: _exportReport,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56DB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Summary Cards - Using Wrap to prevent overflow
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildSummaryCard('Total Collections', 'Rs. $total', '+12%', Icons.account_balance_wallet, Colors.blue),
                _buildSummaryCard('Pending Payments', 'Rs. $pending', '+5%', Icons.pending, Colors.orange),
                _buildSummaryCard('Completed Payments', 'Rs. $paid', '+15%', Icons.check_circle, Colors.green),
                _buildSummaryCard('Collection Rate', '$rate%', '+8%', Icons.percent, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            
            // Payment Methods + Top Services Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        const Text('Payment Methods', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildPaymentMethodRow('Pay Online', 4500, 5),
                        const SizedBox(height: 12),
                        _buildPaymentMethodRow('Pay at Counter', 3500, 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        const Text('Top Services by Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildServiceRow('Passport Renewal', 10000, 8),
                        const SizedBox(height: 12),
                        _buildServiceRow('Driving License', 6000, 5),
                        const SizedBox(height: 12),
                        _buildServiceRow('NIC Card', 1000, 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Transaction History Table - FIXED with constrained height
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
                    child: Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  // Fixed height container with scroll to prevent overflow
                  SizedBox(
                    height: 400, // Fixed height
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 30,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('Transaction ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Citizen', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Service', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Method', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filtered.map((txn) {
                            final isPaid = txn['status'] == 'paid';
                            return DataRow(cells: [
                              DataCell(Text(txn['id'], style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(txn['citizen'])),
                              DataCell(Text(txn['service'])),
                              DataCell(Text('Rs. ${txn['amount']}')),
                              DataCell(Text(txn['date'])),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A56DB).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(txn['method'], style: const TextStyle(fontSize: 11, color: Color(0xFF1A56DB))),
                              )),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  txn['status'].toUpperCase(),
                                  style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Extra bottom padding
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String change, IconData icon, Color color) {
    return SizedBox(
      width: 220,  // Fixed width to prevent overflow
      child: Container(
        padding: const EdgeInsets.all(16),
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
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(change, style: TextStyle(fontSize: 10, color: change.startsWith('+') ? Colors.green : Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodRow(String method, int amount, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(method == 'Pay Online' ? Icons.qr_code : Icons.payments, color: const Color(0xFF1A56DB)),
          const SizedBox(width: 12),
          Expanded(child: Text(method)),
          Text('Rs. $amount', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count transactions', style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRow(String service, int amount, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment, color: Color(0xFF1A56DB)),
          const SizedBox(width: 12),
          Expanded(child: Text(service)),
          Text('Rs. $amount', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count payments', style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}