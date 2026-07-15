import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide DateFormat;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/models/appointment_model.dart';
import 'package:queuenova_mobile/services/appointment_service.dart';
import 'package:queuenova_mobile/screens/book_appointment_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String selectedFilter = 'Upcoming';
  final List<String> filters = ['Upcoming', 'Past', 'Cancelled'];
  List<AppointmentModel> appointments = [];
  bool isLoading = true;
  String? _error;
  StreamSubscription<List<AppointmentModel>>? _appointmentsSub;

  @override
  void initState() {
    super.initState();
    _watchAppointments();
  }

  @override
  void dispose() {
    _appointmentsSub?.cancel();
    super.dispose();
  }

  // Realtime: re-renders the moment this citizen's appointments change in
  // Firestore (new booking, staff status update, cancellation, reschedule)
  // instead of only on screen load / manual refresh.
  void _watchAppointments() {
    _appointmentsSub = AppointmentService.watchAppointments().listen((apts) {
      if (!mounted) return;
      setState(() {
        appointments = apts.reversed.toList();
        isLoading = false;
        _error = null;
      });
    }, onError: (Object e) {
      debugPrint('watchAppointments error: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _error = e.toString();
      });
    });
  }

  Future<void> _loadAppointments() async {
    setState(() => isLoading = true);
    try {
      final apts = await AppointmentService.getAppointments();
      if (!mounted) return;
      setState(() {
        appointments = apts.reversed.toList();
        isLoading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('_loadAppointments error: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<AppointmentModel> get filteredBookings {
    // Compare by calendar day, not exact clock time — AppointmentModel.date
    // is always midnight of the appointment day (the actual time lives in
    // the separate `time` field), so comparing against DateTime.now()
    // directly would mark today's not-yet-happened appointment as "Past"
    // the moment midnight ticks over.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (selectedFilter == 'Upcoming') {
      return appointments.where((b) =>
        !b.date.isBefore(today) &&
        (b.status == 'Confirmed' || b.status == 'Pending')
      ).toList();
    } else if (selectedFilter == 'Past') {
      return appointments.where((b) =>
        b.date.isBefore(today) || b.status == 'Completed'
      ).toList();
    } else {
      return appointments.where((b) => b.status == 'Cancelled').toList();
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Confirmed': return AppColors.success;
      case 'Pending': return AppColors.warning;
      case 'Completed': return AppColors.info;
      case 'Cancelled': return AppColors.error;
      default: return AppColors.grey;
    }
  }

  Future<void> _cancelBooking(AppointmentModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('cancel_booking'.tr()),
        content: Text('cancel_booking_confirm'.tr(args: [booking.service])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('no_button'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('yes_cancel'.tr()),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await AppointmentService.updateAppointmentStatus(booking.id, 'Cancelled');
      await _loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('booking_cancelled'.tr()), backgroundColor: AppColors.success),
        );
      }
    }
  }

  Future<void> _rescheduleBooking(AppointmentModel booking) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookAppointmentScreen(rescheduleAppointment: booking),
      ),
    );
    if (result == true) {
      await _loadAppointments();
    }
  }

  void _showQRCode(AppointmentModel booking) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(booking.service,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('token_label'.tr(args: [booking.token]),
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('dd MMM yyyy').format(booking.date)}  •  ${booking.time}',
                style: const TextStyle(fontSize: 13, color: AppColors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightBlue, width: 2),
                ),
                child: QrImageView(
                  data: booking.qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('show_qr_at_center'.tr(),
                    style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue),
                  child: Text('close'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookings = filteredBookings;

    return Scaffold(
      appBar: AppBar(
        title: Text('my_bookings'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      'failed_load_bookings'.tr(args: ['$_error']),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  height: 45,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      final isSelected = selectedFilter == filter;
                      return FilterChip(
                        label: Text(filter.toLowerCase().tr()),
                        selected: isSelected,
                        onSelected: (_) => setState(() => selectedFilter = filter),
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: bookings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today, size: 64, color: AppColors.grey),
                              const SizedBox(height: 16),
                              Text('no_bookings'.tr(args: [selectedFilter.toLowerCase().tr()]), style: TextStyle(color: AppColors.grey)),
                              const SizedBox(height: 8),
                              Text('book_to_get_started'.tr(), style: TextStyle(fontSize: 12, color: AppColors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: bookings.length,
                          itemBuilder: (context, index) {
                            final booking = bookings[index];
                            final today = DateTime.now();
                            final isUpcoming = !booking.date.isBefore(DateTime(today.year, today.month, today.day));
                            final isPending = booking.status == 'Pending';
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: _getServiceColor(booking.service).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(_getServiceIcon(booking.service), color: _getServiceColor(booking.service)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(booking.service, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                  const SizedBox(height: 4),
                                                  Text(booking.office, style: TextStyle(fontSize: 12, color: AppColors.grey)),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: getStatusColor(booking.status).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isPending)
                                                    const Icon(Icons.hourglass_empty, size: 12, color: AppColors.warning),
                                                  if (isPending) const SizedBox(width: 4),
                                                  Text(
                                                    booking.status,
                                                    style: TextStyle(fontSize: 11, color: getStatusColor(booking.status), fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _buildDetailChip(Icons.calendar_today, DateFormat('dd MMM yyyy').format(booking.date)),
                                            const SizedBox(width: 8),
                                            _buildDetailChip(Icons.access_time, booking.time),
                                            const SizedBox(width: 8),
                                            _buildDetailChip(Icons.confirmation_number, 'token_label'.tr(args: [booking.token])),
                                          ],
                                        ),
                                        if (isPending)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 12),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'pending_approval'.tr(),
                                                      style: const TextStyle(fontSize: 11, color: AppColors.warning),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (booking.status != 'Cancelled' && isUpcoming && !isPending)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.offWhite,
                                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _showQRCode(booking),
                                              icon: const Icon(Icons.qr_code, size: 18),
                                              label: Text('qr_code'.tr()),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: AppColors.primaryBlue),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _rescheduleBooking(booking),
                                              icon: const Icon(Icons.edit_calendar, size: 18),
                                              label: Text('reschedule'.tr()),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: AppColors.warning),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _cancelBooking(booking),
                                              icon: const Icon(Icons.cancel, size: 18),
                                              label: Text('cancel'.tr()),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: AppColors.error),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppColors.primaryBlue),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String service) {
    if (service.contains('Passport')) return Icons.airplane_ticket;
    if (service.contains('NIC') || service.contains('National')) return Icons.badge;
    if (service.contains('Driving')) return Icons.directions_car;
    if (service.contains('Birth')) return Icons.celebration;
    return Icons.description;
  }

  Color _getServiceColor(String service) {
    if (service.contains('Passport')) return AppColors.primaryBlue;
    if (service.contains('NIC') || service.contains('National')) return AppColors.success;
    if (service.contains('Driving')) return AppColors.warning;
    if (service.contains('Birth')) return AppColors.accentTeal;
    return AppColors.greyDark;
  }
}