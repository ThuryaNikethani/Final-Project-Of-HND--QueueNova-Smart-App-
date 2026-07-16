import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/models/appointment_model.dart';
import 'package:queuenova_mobile/services/appointment_service.dart';

const Map<String, String> _kStatusKeys = {
  'All': 'filter_all',
  'Confirmed': 'confirmed',
  'Completed': 'completed_status',
  'Cancelled': 'cancelled',
  'Pending': 'pending',
};

String _statusLabel(String status) => (_kStatusKeys[status] ?? status).tr();

class RequestTrackingScreen extends StatefulWidget {
  const RequestTrackingScreen({super.key});

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends State<RequestTrackingScreen> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled'];
  List<AppointmentModel> appointments = [];
  bool isLoading = true;
  StreamSubscription<List<AppointmentModel>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = AppointmentService.watchAppointments().listen((apts) {
      if (!mounted) return;
      setState(() {
        appointments = apts.reversed.toList();
        isLoading = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    final apts = await AppointmentService.getAppointments();
    if (!mounted) return;
    setState(() {
      appointments = apts.reversed.toList();
    });
  }

  List<AppointmentModel> get filteredAppointments {
    if (selectedFilter == 'All') return appointments;
    return appointments.where((a) => a.status == selectedFilter).toList();
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending': return AppColors.warning;
      case 'Confirmed': return AppColors.success;
      case 'Completed': return AppColors.info;
      case 'Cancelled': return AppColors.error;
      default: return AppColors.grey;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'Pending': return 'pending_approval'.tr();
      case 'Confirmed': return 'appointment_confirmed_status_text'.tr();
      case 'Completed': return 'service_completed_successfully'.tr();
      case 'Cancelled': return 'appointment_cancelled_status_text'.tr();
      default: return status;
    }
  }

  double getProgress(String status) {
    switch (status) {
      case 'Confirmed': return 0.3;
      case 'Completed': return 1.0;
      default: return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('track_requests_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
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
                      return FilterChip(
                        label: Text(_statusLabel(filter)),
                        selected: selectedFilter == filter,
                        onSelected: (_) => setState(() => selectedFilter = filter),
                        selectedColor: AppColors.primaryBlue,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(color: selectedFilter == filter ? Colors.white : AppColors.textPrimary),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAppointments,
                    child: filteredAppointments.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.inbox, size: 64, color: AppColors.grey),
                                    const SizedBox(height: 16),
                                    Text('no_requests_found'.tr(), style: const TextStyle(color: AppColors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredAppointments.length,
                          itemBuilder: (context, index) {
                            final apt = filteredAppointments[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: getStatusColor(apt.status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(Icons.request_page, color: getStatusColor(apt.status)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(apt.service, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(apt.office, style: TextStyle(fontSize: 12, color: AppColors.grey)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: getStatusColor(apt.status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _statusLabel(apt.status),
                                          style: TextStyle(fontSize: 11, color: getStatusColor(apt.status), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value: getProgress(apt.status),
                                    backgroundColor: AppColors.greyLight,
                                    valueColor: AlwaysStoppedAnimation<Color>(getStatusColor(apt.status)),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(getStatusText(apt.status), style: TextStyle(fontSize: 11, color: AppColors.grey)),
                                      Text(DateFormat('dd MMM yyyy').format(apt.date), style: TextStyle(fontSize: 11, color: AppColors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('token_label'.tr(args: [apt.token]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
                ),
              ],
            ),
    );
  }
}