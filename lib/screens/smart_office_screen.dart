import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/screens/book_appointment_screen.dart';
import 'package:queuenova_mobile/services/ml_prediction_service.dart';

class SmartOfficeScreen extends StatefulWidget {
  const SmartOfficeScreen({super.key});

  @override
  State<SmartOfficeScreen> createState() => _SmartOfficeScreenState();
}

class _SmartOfficeScreenState extends State<SmartOfficeScreen> {
  // Static office info — name, address, distance are fixed; crowd/wait/recommended come from ML
  static const List<Map<String, dynamic>> _staticOffices = [
    {
      'name': 'Colombo Divisional Secretariat',
      'address': 'Colombo 01',
      'distance': '2.5 km',
      'officeId': 'Divisional Secretariat - Colombo',
    },
    {
      'name': 'RMV - Kiribathgoda',
      'address': 'Kiribathgoda',
      'distance': '12.8 km',
      'officeId': 'RMV - Kiribathgoda',
    },
    {
      'name': 'Nugegoda Divisional Secretariat',
      'address': 'Nugegoda',
      'distance': '6.5 km',
      'officeId': 'Divisional Secretariat - Nugegoda',
    },
    {
      'name': 'RMV - Werahera',
      'address': 'Werahera, Biyagama',
      'distance': '15.3 km',
      'officeId': 'RMV - Werahera',
    },
    {
      'name': 'Passport Office - Battaramulla',
      'address': 'Battaramulla',
      'distance': '8.2 km',
      'officeId': 'Passport Office - Battaramulla',
    },
    {
      'name': 'Kandy Divisional Secretariat',
      'address': 'Kandy',
      'distance': '115 km',
      'officeId': 'Divisional Secretariat - Kandy',
    },
  ];

  // ML-predicted data per officeId
  Map<String, QueuePrediction> _predictions = {};
  Timer? _refreshTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshPredictions();
    // Refresh ML predictions every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _refreshPredictions();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshPredictions() {
    final now = DateTime.now();
    final newPredictions = <String, QueuePrediction>{};
    for (final office in _staticOffices) {
      final officeId = office['officeId'] as String;
      newPredictions[officeId] = MLPredictionService.predict(
        officeName: officeId,
        time: now,
      );
    }
    if (mounted) {
      setState(() {
        _predictions = newPredictions;
        _isLoading = false;
      });
    }
  }

  // Build the merged office map the way the original code expected it
  List<Map<String, dynamic>> get _offices {
    return _staticOffices.map((static_) {
      final id = static_['officeId'] as String;
      final pred = _predictions[id];
      return {
        'name': static_['name'],
        'address': static_['address'],
        'distance': static_['distance'],
        'officeId': id,
        'crowd': pred?.crowdLevel.label ?? 'Low',
        'wait': pred != null ? '${pred.estimatedWaitMinutes} min' : '-- min',
        'recommended': pred != null && pred.crowdLevel != CrowdLevel.high,
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
    final offices = _offices;
    final recommendedOffices = offices.where((o) => o['recommended'] == true).toList();
    final otherOffices = offices.where((o) => o['recommended'] == false).toList();

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
                label: office['crowd'],
                color: crowdColor,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                icon: Icons.timer,
                label: office['wait'],
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('directions_coming_soon'.tr()),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
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
