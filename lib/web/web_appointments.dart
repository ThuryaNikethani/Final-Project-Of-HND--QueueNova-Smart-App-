import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';
import 'web_notifications.dart';
import 'web_payment_reports.dart';
import 'web_role_model.dart';

class WebAppointments extends StatefulWidget {
  final UserRole userRole;
  final String staffId;

  const WebAppointments({super.key, required this.userRole, required this.staffId});

  @override
  State<WebAppointments> createState() => _WebAppointmentsState();
}

class _WebAppointmentsState extends State<WebAppointments> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled'];

  List<Map<String, dynamic>> appointments = [];
  socket_io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadAppointmentsFromApi();
    _socket = socket_io.io(
      WebApiService.apiOrigin,
      socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket!.on('appointment_update', (_) => _loadAppointmentsFromApi());
    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  /// Backend status values aren't always the Title-Case buckets this screen
  /// filters by ('scheduled' is the column default for legacy/unconfirmed
  /// rows) — this maps whatever's stored to one of Pending/Confirmed/
  /// Completed/Cancelled.
  String _mapStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'confirmed': return 'Confirmed';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return 'Pending';
    }
  }

  Future<void> _loadAppointmentsFromApi() async {
    final rows = await WebApiService.getAppointments();
    if (!mounted) return;
    setState(() {
      appointments = rows.map((r) {
        String dateDisplay = r['date']?.toString() ?? '';
        try {
          dateDisplay = DateFormat('d MMM yyyy').format(DateTime.parse(dateDisplay));
        } catch (_) {}
        return {
          'id': r['id'],
          'citizen': r['citizen_name'] ?? '',
          'nic': r['citizen_nic'],
          'service': r['service'] ?? '',
          'office': r['office'] ?? '',
          'date': dateDisplay,
          'time': r['time'] ?? '',
          'status': _mapStatus(r['status']?.toString()),
          'token': r['token'] ?? '',
          'fee': double.tryParse(r['fee_amount']?.toString() ?? '') ?? 0,
          'paymentStatus': r['payment_status'] ?? 'pending',
          'paymentMethod': r['payment_method'] ?? '',
        };
      }).toList();
    });
  }

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

  String _statusLabel(String status) {
    switch (status) {
      case 'Pending': return 'pending'.tr();
      case 'Confirmed': return 'confirmed'.tr();
      case 'Completed': return 'completed_status'.tr();
      case 'Cancelled': return 'cancelled'.tr();
      case 'All': return 'web_status_all'.tr();
      default: return status;
    }
  }

  /// Notifies the citizen identified by [nic] via the `notifications`
  /// collection (the same one the citizen app's Notifications screen reads
  /// live). Looks the uid up through `nic_index`, same as login does.
  Future<void> _notifyCitizenByNic({
    required String? nic,
    required String title,
    required String message,
  }) async {
    if (nic == null || nic.isEmpty) return;
    try {
      final indexDoc = await FirebaseFirestore.instance.collection('nic_index').doc(nic.toUpperCase()).get();
      final uid = indexDoc.data()?['uid'] as String?;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('notifications').add({
        'uid': uid,
        'title': title,
        'message': message,
        'type': 'appointment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyCitizenByNic error: $e');
    }
  }

  void _confirmPayment(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_confirm_payment_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('web_citizen_label'.tr(args: ['${appointment['citizen']}'])),
            Text('web_service_colon_label'.tr(args: ['${appointment['service']}'])),
            Text('web_amount_label'.tr(args: ['${appointment['fee']}'])),
            const SizedBox(height: 16),
            Text('web_confirm_payment_prompt'.tr()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await WebApiService.updateAppointmentStatus(
                appointment['id'] as String,
                paymentStatus: 'paid',
                updatedBy: 'Admin Officer',
              );
              _notifyCitizenByNic(
                nic: appointment['nic'] as String?,
                title: 'Payment Confirmed',
                message: 'Your payment of Rs. ${appointment['fee']} for ${appointment['service']} (Token ${appointment['token']}) has been confirmed.',
              );
              await _loadAppointmentsFromApi();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('web_payment_confirmed_message'.tr()), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('web_confirm_payment_title'.tr()),
          ),
        ],
      ),
    );
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
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
                  Text(
                    'web_appointment_details'.tr(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow('web_appointment_id_col'.tr(), appointment['id']),
              const SizedBox(height: 12),
              _buildDetailRow('web_citizen_name'.tr(), appointment['citizen']),
              const SizedBox(height: 12),
              _buildDetailRow('web_nic_number'.tr(), appointment['nic']),
              const SizedBox(height: 12),
              _buildDetailRow('web_detail_service'.tr(), appointment['service']),
              const SizedBox(height: 12),
              _buildDetailRow('web_detail_office'.tr(), appointment['office']),
              const SizedBox(height: 12),
              _buildDetailRow('web_col_date'.tr(), appointment['date']),
              const SizedBox(height: 12),
              _buildDetailRow('web_col_time'.tr(), appointment['time']),
              const SizedBox(height: 12),
              _buildDetailRow('web_detail_token'.tr(), appointment['token']),
              const SizedBox(height: 12),
              _buildDetailRow('web_fee_label'.tr(), 'Rs. ${appointment['fee']}'),
              const SizedBox(height: 12),
              _buildPaymentRow('web_payment_status_label'.tr(), appointment['paymentStatus'], appointment['paymentMethod']),
              const SizedBox(height: 12),
              _buildDetailRow('web_col_status'.tr(), _statusLabel(appointment['status'] as String), isStatus: true, statusColor: getStatusColor(appointment['status'])),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (appointment['paymentStatus'] == 'pending')
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _confirmPayment(appointment);
                      },
                      icon: const Icon(Icons.payment),
                      label: Text('web_confirm_payment_title'.tr()),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  if (appointment['status'] == 'Pending')
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await WebApiService.updateAppointmentStatus(
                          appointment['id'] as String,
                          status: 'Confirmed',
                          updatedBy: 'Admin Officer',
                        );
                        _notifyCitizenByNic(
                          nic: appointment['nic'] as String?,
                          title: 'Appointment Confirmed',
                          message: 'Your ${appointment['service']} appointment (Token ${appointment['token']}) has been confirmed.',
                        );
                        await _loadAppointmentsFromApi();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('web_appointment_confirmed_message'.tr()), backgroundColor: Colors.green),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: Text('web_confirm_button'.tr()),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                    label: Text('close'.tr()),
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
        SizedBox(
          width: 120,
          child: Text(
            'web_payment_label'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
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
                      paymentStatus == 'paid' ? 'web_paid'.tr() : 'pending'.tr(),
                      style: TextStyle(
                        color: paymentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'web_via_method'.tr(args: [paymentMethod]),
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
        title: Text('web_appointment_management_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (pendingPayments > 0)
            Container(
              margin: const EdgeInsets.only(right: 20),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'web_view_payment_reports_tooltip'.tr(),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WebPaymentReports()),
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.payment, color: Colors.grey),
                    Positioned(
                      right: -4,
                      top: -4,
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
            ),
          Container(
            margin: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.notifications_none, color: Colors.grey),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebNotifications(userRole: widget.userRole, staffId: widget.staffId),
                    ),
                  ),
                ),
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
                    Text('web_admin_label'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('web_administrator_label'.tr(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                _buildStatCard('web_total_appointments'.tr(), appointments.length.toString(), Icons.calendar_today, Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard('pending'.tr(), appointments.where((a) => a['status'] == 'Pending').length.toString(), Icons.pending, Colors.orange),
                const SizedBox(width: 16),
                _buildStatCard('confirmed'.tr(), appointments.where((a) => a['status'] == 'Confirmed').length.toString(), Icons.check_circle, Colors.green),
                const SizedBox(width: 16),
                _buildStatCard('web_pending_payments'.tr(), pendingPayments.toString(), Icons.payment, Colors.red),
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
                    label: Text(_statusLabel(filter)),
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
                    columns: [
                      DataColumn(label: Text('web_appointment_id_col'.tr())),
                      DataColumn(label: Text('web_col_citizen'.tr())),
                      DataColumn(label: Text('web_col_service'.tr())),
                      DataColumn(label: Text('web_col_date'.tr())),
                      DataColumn(label: Text('web_col_time'.tr())),
                      DataColumn(label: Text('web_fee_label'.tr())),
                      DataColumn(label: Text('web_col_payment'.tr())),
                      DataColumn(label: Text('web_col_status'.tr())),
                      DataColumn(label: Text('web_col_action'.tr())),
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
                                apt['paymentStatus'] == 'paid' ? 'web_paid'.tr() : 'pending'.tr(),
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
                          child: Text(_statusLabel(apt['status'] as String), style: TextStyle(color: statusColor)),
                        )),
                        DataCell(Row(
                          children: [
                            if (apt['paymentStatus'] == 'pending')
                              IconButton(
                                icon: const Icon(Icons.payment, color: Colors.green),
                                onPressed: () => _confirmPayment(apt),
                                tooltip: 'web_confirm_payment_title'.tr(),
                              ),
                            IconButton(
                              icon: const Icon(Icons.visibility, color: Color(0xFF1A56DB)),
                              onPressed: () => _showAppointmentDetails(apt),
                              tooltip: 'web_view_details_tooltip'.tr(),
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