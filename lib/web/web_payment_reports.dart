import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebPaymentReports extends StatefulWidget {
  const WebPaymentReports({super.key});

  @override
  State<WebPaymentReports> createState() => _WebPaymentReportsState();
}

class _WebPaymentReportsState extends State<WebPaymentReports> {
  String selectedPeriod = 'This Month';
  final List<String> periods = ['Today', 'This Week', 'This Month', 'This Year'];

  bool _loading = true;
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> paymentMethods = [];
  List<Map<String, dynamic>> topServices = [];

  int _periodToDays(String period) {
    switch (period) {
      case 'Today': return 1;
      case 'This Week': return 7;
      case 'This Month': return 30;
      case 'This Year': return 365;
      default: return 30;
    }
  }

  num? _asNum(dynamic v) => v == null ? null : num.tryParse(v.toString());

  @override
  void initState() {
    super.initState();
    _loadPaymentReports();
  }

  Future<void> _loadPaymentReports() async {
    setState(() => _loading = true);
    final data = await WebApiService.getPaymentReports(days: _periodToDays(selectedPeriod));
    if (!mounted) return;
    setState(() {
      transactions = ((data['transactions'] as List?) ?? []).cast<Map<String, dynamic>>().map((t) {
        return {
          'id': t['id']?.toString() ?? '',
          'citizen': t['citizen_name']?.toString() ?? '',
          'service': t['service']?.toString() ?? '',
          'amount': _asNum(t['fee_amount'])?.round() ?? 0,
          'date': t['date']?.toString().substring(0, 10) ?? '',
          'status': t['payment_status']?.toString() ?? 'pending',
          'method': t['payment_method']?.toString() ?? '',
        };
      }).toList();
      paymentMethods = ((data['byMethod'] as List?) ?? []).cast<Map<String, dynamic>>().map((m) {
        return {
          'method': m['payment_method']?.toString() ?? '',
          'amount': _asNum(m['total'])?.round() ?? 0,
          'count': _asNum(m['count'])?.toInt() ?? 0,
        };
      }).toList();
      topServices = ((data['byService'] as List?) ?? []).cast<Map<String, dynamic>>().map((s) {
        return {
          'service': s['service']?.toString() ?? '',
          'amount': _asNum(s['total'])?.round() ?? 0,
          'count': _asNum(s['count'])?.toInt() ?? 0,
        };
      }).toList();
      _loading = false;
    });
  }

  // Already scoped to the selected period by the backend query.
  List<Map<String, dynamic>> get filteredTransactions => transactions;

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
      SnackBar(content: Text('web_report_exported_success'.tr()), backgroundColor: Colors.green),
    );
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'Today': return 'web_period_today'.tr();
      case 'This Week': return 'web_period_this_week'.tr();
      case 'This Month': return 'web_period_this_month'.tr();
      case 'This Year': return 'web_period_this_year'.tr();
      default: return period;
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'Pay Online': return 'web_pay_online'.tr();
      case 'Pay at Counter': return 'web_pay_at_counter'.tr();
      default: return method;
    }
  }

  void _showTransactionListDialog(String title, List<Map<String, dynamic>> txns) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: txns.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('web_no_data_yet'.tr(), style: const TextStyle(color: Colors.grey)),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: txns.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = txns[index];
                      final isPaid = t['status'] == 'paid';
                      return ListTile(
                        dense: true,
                        title: Text('${t['citizen']} — ${t['service']}'),
                        subtitle: Text('${t['id']} • ${t['date']} • ${_methodLabel(t['method'] as String)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Rs. ${t['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              (isPaid ? 'web_paid' : 'pending').tr().toUpperCase(),
                              style: TextStyle(fontSize: 10, color: isPaid ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showCollectionRateDetails(double total, double pending, double paid, String rate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_collection_rate'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('web_total_collections'.tr(), 'Rs. ${total.toStringAsFixed(0)}'),
            const Divider(),
            _buildSummaryRow('web_completed_payments'.tr(), 'Rs. ${paid.toStringAsFixed(0)}'),
            const Divider(),
            _buildSummaryRow('web_pending_payments'.tr(), 'Rs. ${pending.toStringAsFixed(0)}'),
            const Divider(),
            _buildSummaryRow('web_collection_rate'.tr(), '$rate%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
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
        title: Text('web_menu_payment_reports'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  children: [
                    Text('web_manager_label'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('web_role_department_manager'.tr(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(  // ← FIX: Added SingleChildScrollView to prevent overflow
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
                      items: periods.map((p) => DropdownMenuItem(value: p, child: Text(_periodLabel(p)))).toList(),
                      onChanged: (v) {
                        setState(() => selectedPeriod = v!);
                        _loadPaymentReports();
                      },
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _exportReport,
                  icon: const Icon(Icons.download),
                  label: Text('web_export_report_button'.tr()),
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
                _buildSummaryCard(
                  'web_total_collections'.tr(), 'Rs. ${total.toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.blue,
                  onTap: () => _showTransactionListDialog('web_total_collections'.tr(), filtered),
                ),
                _buildSummaryCard(
                  'web_pending_payments'.tr(), 'Rs. ${pending.toStringAsFixed(0)}', Icons.pending, Colors.orange,
                  onTap: () => _showTransactionListDialog('web_pending_payments'.tr(), filtered.where((t) => t['status'] == 'pending').toList()),
                ),
                _buildSummaryCard(
                  'web_completed_payments'.tr(), 'Rs. ${paid.toStringAsFixed(0)}', Icons.check_circle, Colors.green,
                  onTap: () => _showTransactionListDialog('web_completed_payments'.tr(), filtered.where((t) => t['status'] == 'paid').toList()),
                ),
                _buildSummaryCard(
                  'web_collection_rate'.tr(), '$rate%', Icons.percent, Colors.purple,
                  onTap: () => _showCollectionRateDetails(total, pending, paid, rate),
                ),
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
                        Text('web_payment_methods_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (paymentMethods.isEmpty)
                          Text('web_no_data_yet'.tr(), style: const TextStyle(color: Colors.grey))
                        else
                          for (int i = 0; i < paymentMethods.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _buildPaymentMethodRow(
                              paymentMethods[i]['method'] as String,
                              paymentMethods[i]['amount'] as int,
                              paymentMethods[i]['count'] as int,
                              onTap: () => _showTransactionListDialog(
                                _methodLabel(paymentMethods[i]['method'] as String),
                                filtered.where((t) => t['method'] == paymentMethods[i]['method']).toList(),
                              ),
                            ),
                          ],
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
                        Text('web_top_services_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (topServices.isEmpty)
                          Text('web_no_data_yet'.tr(), style: const TextStyle(color: Colors.grey))
                        else
                          for (int i = 0; i < topServices.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _buildServiceRow(
                              topServices[i]['service'] as String,
                              topServices[i]['amount'] as int,
                              topServices[i]['count'] as int,
                              onTap: () => _showTransactionListDialog(
                                topServices[i]['service'] as String,
                                filtered.where((t) => t['service'] == topServices[i]['service']).toList(),
                              ),
                            ),
                          ],
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
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('web_transaction_history_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          columns: [
                            DataColumn(label: Text('web_transaction_id_col'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('web_col_citizen'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('web_col_service'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('web_col_amount'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('web_col_date'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('web_col_method'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('web_col_status'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
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
                                child: Text(_methodLabel(txn['method'] as String), style: const TextStyle(fontSize: 11, color: Color(0xFF1A56DB))),
                              )),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  (isPaid ? 'web_paid' : 'pending').tr().toUpperCase(),
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return SizedBox(
      width: 220,  // Fixed width to prevent overflow
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodRow(String method, int amount, int count, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(method == 'Pay Online' ? Icons.qr_code : Icons.payments, color: const Color(0xFF1A56DB)),
            const SizedBox(width: 12),
            Expanded(child: Text(_methodLabel(method))),
            Text('Rs. $amount', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('web_count_transactions'.tr(args: ['$count']), style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceRow(String service, int amount, int count, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
              child: Text('web_count_payments'.tr(args: ['$count']), style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}