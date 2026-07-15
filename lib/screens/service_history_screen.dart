import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide DateFormat;
import 'package:intl/intl.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/models/appointment_model.dart';
import 'package:queuenova_mobile/services/appointment_service.dart';

const Map<String, String> _kHistoryStatusKeys = {
  'All': 'filter_all',
  'Pending': 'pending',
  'Confirmed': 'confirmed',
  'Completed': 'completed_status',
  'Cancelled': 'cancelled',
};

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled'];

  List<AppointmentModel> historyList = [];
  bool isLoading = true;
  StreamSubscription<List<AppointmentModel>>? _appointmentsSub;

  @override
  void initState() {
    super.initState();
    _appointmentsSub = AppointmentService.watchAppointments().listen((apts) {
      if (!mounted) return;
      setState(() {
        historyList = apts;
        isLoading = false;
      });
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    });
  }

  @override
  void dispose() {
    _appointmentsSub?.cancel();
    super.dispose();
  }

  List<AppointmentModel> get filteredHistory {
    if (selectedFilter == 'All') return historyList;
    return historyList.where((h) => h.status == selectedFilter).toList();
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending': return AppColors.warning;
      case 'Confirmed': return AppColors.info;
      case 'Completed': return AppColors.success;
      case 'Cancelled': return AppColors.error;
      default: return AppColors.grey;
    }
  }

  String getStatusIcon(String status) {
    switch (status) {
      case 'Pending': return '⏳';
      case 'Confirmed': return '🔄';
      case 'Completed': return '✅';
      case 'Cancelled': return '❌';
      default: return '📋';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('service_history'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Summary
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('stat_total_label'.tr(), historyList.length.toString(), Icons.receipt_long),
                      _buildStatItem('completed_status'.tr(), historyList.where((h) => h.status == 'Completed').length.toString(), Icons.check_circle),
                      _buildStatItem('pending'.tr(), historyList.where((h) => h.status == 'Pending').length.toString(), Icons.pending),
                    ],
                  ),
                ),
                // Filters
                Container(
                  height: 45,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      return FilterChip(
                        label: Text(_kHistoryStatusKeys[filter]!.tr()),
                        selected: selectedFilter == filter,
                        onSelected: (_) => setState(() => selectedFilter = filter),
                        selectedColor: AppColors.primaryBlue,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(color: selectedFilter == filter ? Colors.white : AppColors.textPrimary),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // History List
                Expanded(
                  child: filteredHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 64, color: AppColors.grey.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text('no_service_history_found'.tr(), style: TextStyle(color: AppColors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredHistory.length,
                          itemBuilder: (context, index) {
                            final item = filteredHistory[index];
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
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: getStatusColor(item.status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Center(
                                          child: Text(
                                            getStatusIcon(item.status),
                                            style: const TextStyle(fontSize: 24),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.service,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.office,
                                              style: TextStyle(fontSize: 12, color: AppColors.grey),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today, size: 12, color: AppColors.grey),
                                                const SizedBox(width: 4),
                                                Text(
                                                  DateFormat('dd MMM yyyy').format(item.date),
                                                  style: TextStyle(fontSize: 11, color: AppColors.grey),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(Icons.currency_rupee, size: 12, color: AppColors.grey),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'rupee_amount'.tr(args: [item.feeAmount.toStringAsFixed(0)]),
                                                  style: TextStyle(fontSize: 11, color: AppColors.grey),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: getStatusColor(item.status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _kHistoryStatusKeys[item.status]?.tr() ?? item.status,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: getStatusColor(item.status),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.offWhite,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.local_shipping, size: 16, color: AppColors.primaryBlue),
                                        const SizedBox(width: 8),
                                        Text('tracking_id_label'.tr(), style: TextStyle(fontSize: 12, color: AppColors.grey)),
                                        Text(
                                          item.token,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('tracking_details_coming_soon'.tr()), behavior: SnackBarBehavior.floating),
                                            );
                                          },
                                          child: Text('track_button'.tr()),
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
