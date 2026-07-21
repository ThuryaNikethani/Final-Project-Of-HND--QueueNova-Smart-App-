import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/models/appointment_model.dart';
import 'package:queuenova_mobile/services/appointment_service.dart';
import 'package:queuenova_mobile/models/online_service_request_model.dart';
import 'package:queuenova_mobile/services/online_service_request_service.dart';

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
  // Categorizes tracked items as physical appointments (existing behaviour,
  // unchanged) vs fully-online service requests (new).
  String _category = 'Appointments';

  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled'];
  List<AppointmentModel> appointments = [];
  bool isLoading = true;
  StreamSubscription<List<AppointmentModel>>? _subscription;

  String selectedOnlineFilter = 'All';
  final List<String> onlineFilters = ['All', 'submitted', 'forwarded_to_office', 'office_completed', 'completed', 'rejected'];
  List<OnlineServiceRequestModel> onlineRequests = [];
  bool isLoadingOnline = true;
  StreamSubscription<List<OnlineServiceRequestModel>>? _onlineSubscription;

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

    _onlineSubscription = OnlineServiceRequestService.watchRequests().listen((reqs) {
      if (!mounted) return;
      setState(() {
        onlineRequests = reqs;
        isLoadingOnline = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => isLoadingOnline = false);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _onlineSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    final apts = await AppointmentService.getAppointments();
    if (!mounted) return;
    setState(() {
      appointments = apts.reversed.toList();
    });
  }

  Future<void> _loadOnlineRequests() async {
    final reqs = await OnlineServiceRequestService.getRequests();
    if (!mounted) return;
    setState(() => onlineRequests = reqs);
  }

  List<AppointmentModel> get filteredAppointments {
    if (selectedFilter == 'All') return appointments;
    return appointments.where((a) => a.status == selectedFilter).toList();
  }

  List<OnlineServiceRequestModel> get filteredOnlineRequests {
    if (selectedOnlineFilter == 'All') return onlineRequests;
    return onlineRequests.where((r) => r.status == selectedOnlineFilter).toList();
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

  Color getOnlineStatusColor(String status) {
    switch (status) {
      case 'pending_payment': return AppColors.warning;
      case 'submitted': return AppColors.info;
      case 'forwarded_to_office': return AppColors.primaryBlue;
      case 'office_completed': return const Color(0xFF8B5CF6);
      case 'completed': return AppColors.success;
      case 'rejected': return AppColors.error;
      default: return AppColors.grey;
    }
  }

  double getOnlineProgress(String status) {
    switch (status) {
      case 'submitted': return 0.2;
      case 'forwarded_to_office': return 0.5;
      case 'office_completed': return 0.8;
      case 'completed': return 1.0;
      default: return 0.0;
    }
  }

  String _onlineFilterLabel(String filter) {
    switch (filter) {
      case 'All': return 'All';
      case 'submitted': return 'Submitted';
      case 'forwarded_to_office': return 'Processing';
      case 'office_completed': return 'Ready for Delivery';
      case 'completed': return 'Completed';
      case 'rejected': return 'Rejected';
      default: return filter;
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildCategoryTab('Appointments', Icons.calendar_today_rounded)),
                  Expanded(child: _buildCategoryTab('Online Requests', Icons.cloud_done_rounded)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _category == 'Appointments' ? _buildAppointmentsTab() : _buildOnlineRequestsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String label, IconData icon) {
    final selected = _category == label;
    return GestureDetector(
      onTap: () => setState(() => _category = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppColors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return Column(
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
                      height: MediaQuery.of(context).size.height * 0.5,
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
    );
  }

  Widget _buildOnlineRequestsTab() {
    if (isLoadingOnline) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Container(
          height: 45,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: onlineFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = onlineFilters[index];
              return FilterChip(
                label: Text(_onlineFilterLabel(filter)),
                selected: selectedOnlineFilter == filter,
                onSelected: (_) => setState(() => selectedOnlineFilter = filter),
                selectedColor: AppColors.primaryBlue,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: selectedOnlineFilter == filter ? Colors.white : AppColors.textPrimary),
              );
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadOnlineRequests,
            child: filteredOnlineRequests.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off, size: 64, color: AppColors.grey),
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
                  itemCount: filteredOnlineRequests.length,
                  itemBuilder: (context, index) {
                    final req = filteredOnlineRequests[index];
                    final color = getOnlineStatusColor(req.status);
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
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.cloud_done_rounded, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(req.service, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (req.isExceptionRequest)
                                      const Text('Exception request', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  req.statusLabel,
                                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: getOnlineProgress(req.status),
                            backgroundColor: AppColors.greyLight,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Currently with: ${req.currentlyWithLabel}', style: TextStyle(fontSize: 11, color: AppColors.grey)),
                              Text(DateFormat('dd MMM yyyy').format(req.createdAt), style: TextStyle(fontSize: 11, color: AppColors.grey)),
                            ],
                          ),
                          if (req.status == 'rejected' && (req.rejectionReason ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Reason: ${req.rejectionReason}', style: const TextStyle(fontSize: 11, color: AppColors.error)),
                            ),
                          ],
                          if (req.status == 'completed' && (req.resultDocumentName ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.description, size: 14, color: AppColors.success),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(req.resultDocumentName!, style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }
}
