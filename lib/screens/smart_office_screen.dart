import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/screens/book_appointment_screen.dart';
import 'package:queuenova_mobile/services/ml_prediction_service.dart';
import 'package:queuenova_mobile/services/location_service.dart';
import 'package:queuenova_mobile/services/queue_status_service.dart';

const Map<String, String> _kCrowdLabelKeys = {
  'Low': 'crowd_level_low',
  'Medium': 'crowd_level_medium',
  'High': 'crowd_level_high',
  'Closed': 'crowd_level_closed',
};

// Same service catalogue/labels as book_appointment_screen.dart's service
// picker (duplicated locally — that file's own map is private to its
// library and its own selection logic is left untouched here).
const Map<String, String> _kServiceKeys = {
  'Passport Renewal': 'svc_passport_renewal_name',
  'New Passport Application': 'svc_new_passport_name',
  'National ID Card': 'svc_national_id_name',
  'NIC Replacement': 'svc_nic_replacement_name',
  'Driving License': 'svc_driving_license_name',
  'License Renewal': 'svc_license_renewal_name',
  'Birth Certificate': 'svc_birth_certificate_name',
  'Marriage Certificate': 'svc_marriage_certificate_name',
  'Death Certificate': 'svc_death_certificate_name',
  'Police Clearance': 'svc_police_clearance_name',
  'Visa Services': 'svc_visa_services_name',
  'Land Registration': 'svc_land_registration_name',
};

// Which office type offers each service, so the office list can be narrowed
// to offices that actually provide the service the citizen is booking for.
const Map<String, String> _kServiceOfficeType = {
  'Passport Renewal': 'Passport Office',
  'New Passport Application': 'Passport Office',
  'Visa Services': 'Passport Office',
  'Driving License': 'RMV',
  'License Renewal': 'RMV',
  'National ID Card': 'Divisional Secretariat',
  'NIC Replacement': 'Divisional Secretariat',
  'Birth Certificate': 'Divisional Secretariat',
  'Marriage Certificate': 'Divisional Secretariat',
  'Death Certificate': 'Divisional Secretariat',
  'Police Clearance': 'Divisional Secretariat',
  'Land Registration': 'Divisional Secretariat',
};

class SmartOfficeScreen extends StatefulWidget {
  const SmartOfficeScreen({super.key});

  @override
  State<SmartOfficeScreen> createState() => _SmartOfficeScreenState();
}

class _SmartOfficeScreenState extends State<SmartOfficeScreen> {
  // Static office info — name, address, coordinates are fixed; crowd/wait/
  // recommended come from ML. 'distance' is the fallback shown when Location
  // Access is off or unavailable; when on, real GPS distance replaces it.
  static const List<Map<String, dynamic>> _staticOffices = [
    {
      'name': 'Colombo Divisional Secretariat',
      'address': 'Dam Street, Colombo 12',
      'distance': '2.5 km',
      'officeId': 'Divisional Secretariat - Colombo',
      'type': 'Divisional Secretariat',
      'lat': 6.9410,
      'lng': 79.8510,
    },
    {
      'name': 'RMV - Kiribathgoda',
      'address': 'Kiribathgoda',
      'distance': '12.8 km',
      'officeId': 'RMV - Kiribathgoda',
      'type': 'RMV',
      'lat': 6.9779,
      'lng': 79.9294,
    },
    {
      'name': 'Sri Jayawardanapura Kotte Divisional Secretariat',
      'address': '341/3, Kotte Road, Rajagiriya',
      'distance': '6.5 km',
      'officeId': 'Divisional Secretariat - Nugegoda',
      'type': 'Divisional Secretariat',
      'lat': 6.9067,
      'lng': 79.9021,
    },
    {
      'name': 'RMV - Werahera',
      'address': 'Department of Motor Traffic Road, Boralesgamuwa',
      'distance': '15.3 km',
      'officeId': 'RMV - Werahera',
      'type': 'RMV',
      'lat': 6.8399,
      'lng': 79.9070,
    },
    {
      'name': 'Passport Office - Battaramulla',
      'address': 'Suhurupaya, Sri Subuthipura Road, Battaramulla',
      'distance': '8.2 km',
      'officeId': 'Passport Office - Battaramulla',
      'type': 'Passport Office',
      'lat': 6.9034,
      'lng': 79.9187,
    },
    {
      'name': 'Kandy Four Gravets & Gangawata Korale Divisional Secretariat',
      'address': 'Kandy',
      'distance': '115 km',
      'officeId': 'Divisional Secretariat - Kandy',
      'type': 'Divisional Secretariat',
      'lat': 7.2906,
      'lng': 80.6337,
    },
  ];

  // Real queue stats per officeId ({waiting, avgWaitMinutes, crowdLevel, ...}
  // from the actual Postgres queue_entries table via QueueStatusService).
  Map<String, Map<String, dynamic>> _queueStats = {};
  // Real GPS distance per officeId (km), populated only when Location Access
  // is on and a position fix succeeds. Falls back to the static string otherwise.
  Map<String, double> _liveDistancesKm = {};
  Timer? _refreshTimer;
  io.Socket? _socket;
  bool _isLoading = true;
  // 'All' shows every office (unfiltered — the screen's original behavior).
  // Picking a specific service narrows the list to offices that provide it.
  String selectedService = 'All';

  @override
  void initState() {
    super.initState();
    _refreshQueueStats();
    _refreshLiveDistances();
    // Periodic refresh as a resilience backup — real-time updates normally
    // arrive instantly via the socket below.
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _refreshQueueStats();
    });
    // Live push: refetch the moment any office's queue changes (check-in,
    // call-next, complete, cancel) instead of waiting for the next poll.
    _socket = QueueStatusService.connect(onQueueChanged: _refreshQueueStats);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _refreshLiveDistances() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('location_enabled') ?? true)) return;

    final position = await LocationService.getCurrentPosition();
    if (position == null || !mounted) return;

    final distances = <String, double>{};
    for (final office in _staticOffices) {
      distances[office['officeId'] as String] = LocationService.distanceKm(
        lat1: position.latitude,
        lon1: position.longitude,
        lat2: office['lat'] as double,
        lon2: office['lng'] as double,
      );
    }
    setState(() => _liveDistancesKm = distances);
  }

  Future<void> _refreshQueueStats() async {
    final officeIds = _staticOffices.map((o) => o['officeId'] as String).toList();
    // Real queue stats straight from Postgres queue_entries — waiting count,
    // today's real avg wait, and crowd level bucketed from the real count.
    final results = await Future.wait(
      officeIds.map((id) => QueueStatusService.getOfficeStats(id)),
    );
    if (!mounted) return;
    setState(() {
      _queueStats = {for (var i = 0; i < officeIds.length; i++) officeIds[i]: results[i]};
      _isLoading = false;
    });
  }

  // Build the merged office map the way the original code expected it
  List<Map<String, dynamic>> get _offices {
    final closed = MLPredictionService.isHolidayOrClosed(DateTime.now());
    return _staticOffices.map((static_) {
      final id = static_['officeId'] as String;
      final stats = _queueStats[id];
      final liveKm = _liveDistancesKm[id];
      // Numeric km for the "which office is nearest" comparison — from live
      // GPS when available, else parsed off the static fallback label (e.g.
      // '2.5 km' -> 2.5) so distance-based recommendation still works with
      // Location Access off.
      final double distanceKm = liveKm ??
          double.tryParse((static_['distance'] as String).split(' ').first) ??
          double.infinity;
      final avgWait = stats?['avgWaitMinutes'] as num?;
      return {
        'name': static_['name'],
        'address': static_['address'],
        'distance': liveKm != null ? '${liveKm.toStringAsFixed(1)} km' : static_['distance'],
        'distanceKm': distanceKm,
        'officeId': id,
        'type': static_['type'],
        // Real crowd level from the actual waiting count (bucketed
        // server-side), 'Closed' when outside operating hours/holidays.
        // No synthetic fallback — an empty office honestly shows Low/0.
        'crowd': closed ? 'Closed' : (stats?['crowdLevel'] as String? ?? 'Low'),
        'waitMinutes': closed ? null : avgWait?.round(),
      };
    }).toList();
  }

  Color getCrowdColor(String crowd) {
    switch (crowd) {
      case 'Low':
        return AppColors.success;
      case 'Medium':
        return AppColors.warning;
      case 'High':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  Future<void> _openDirections(BuildContext context, Map<String, dynamic> office) async {
    final destination = Uri.encodeComponent('${office['name']}, ${office['address']}, Sri Lanka');
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destination');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('could_not_open_maps'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToBookAppointment(BuildContext context, Map<String, dynamic> office) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookAppointmentScreen(
          preSelectedOffice: office['officeId'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allOffices = _offices;
    // Narrow to offices that provide the selected service. 'All' (default)
    // keeps every office, matching the screen's original behavior exactly.
    final requiredType = _kServiceOfficeType[selectedService];
    final offices = requiredType == null
        ? allOffices
        : allOffices.where((o) => o['type'] == requiredType).toList();

    // "Recommended" = not crowded AND on the closer side among the current
    // candidates, so the AI banner reflects both queue length and distance
    // rather than crowd level alone.
    final distances = offices
        .map((o) => o['distanceKm'] as double)
        .where((d) => d.isFinite)
        .toList();
    final avgDistanceKm = distances.isEmpty
        ? double.infinity
        : distances.reduce((a, b) => a + b) / distances.length;

    final officesWithRecommendation = offices.map((o) {
      final crowd = o['crowd'] as String;
      final notCrowded = crowd == 'Low' || crowd == 'Medium';
      final isNear = (o['distanceKm'] as double) <= avgDistanceKm;
      return {...o, 'recommended': notCrowded && isNear};
    }).toList();

    final recommendedOffices = officesWithRecommendation.where((o) => o['recommended'] == true).toList();
    final otherOffices = officesWithRecommendation.where((o) => o['recommended'] == false).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('smart_office'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // AI Recommendation Banner
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentBlue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ai_recommendations'.tr(),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ai_recommendations_body'.tr(args: ['${recommendedOffices.length}']),
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Service filter — narrows offices to ones offering the
                  // selected service; 'All' (default) shows every office,
                  // identical to the screen's original behavior.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'select_service'.tr(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _kServiceKeys.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final service = index == 0 ? 'All' : _kServiceKeys.keys.elementAt(index - 1);
                        final label = index == 0 ? 'filter_all'.tr() : _kServiceKeys[service]!.tr();
                        final isSelected = selectedService == service;
                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) => setState(() => selectedService = service),
                          selectedColor: AppColors.primaryBlue,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Recommended Offices Section
                  if (recommendedOffices.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'recommended_for_you'.tr(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...recommendedOffices.map((office) => _buildOfficeCard(context, office, isRecommended: true)),
                  ],
                  const SizedBox(height: 16),
                  if (offices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.location_off, size: 56, color: AppColors.grey),
                          const SizedBox(height: 12),
                          Text('no_services_found'.tr(), style: const TextStyle(color: AppColors.grey)),
                        ],
                      ),
                    )
                  else ...[
                    // All Offices Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'all_service_centers'.tr(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...otherOffices.map((office) => _buildOfficeCard(context, office, isRecommended: false)),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildOfficeCard(BuildContext context, Map<String, dynamic> office, {required bool isRecommended}) {
    final crowdColor = getCrowdColor(office['crowd']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRecommended ? AppColors.lightBlue : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isRecommended ? Border.all(color: AppColors.primaryBlue, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
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
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.location_city, color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            office['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'best'.tr(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      office['address'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.people,
                label: _kCrowdLabelKeys[office['crowd']]!.tr(),
                color: crowdColor,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                icon: Icons.timer,
                label: office['waitMinutes'] != null
                    ? 'minutes_suffix'.tr(args: ['${office['waitMinutes']}'])
                    : 'wait_time_unknown'.tr(),
                color: AppColors.info,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                icon: Icons.location_on,
                label: office['distance'],
                color: AppColors.grey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _navigateToBookAppointment(context, office),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('book'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openDirections(context, office),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('directions'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
