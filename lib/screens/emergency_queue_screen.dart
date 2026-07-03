import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyQueueScreen extends StatefulWidget {
  const EmergencyQueueScreen({super.key});

  @override
  State<EmergencyQueueScreen> createState() => _EmergencyQueueScreenState();
}

class _EmergencyQueueScreenState extends State<EmergencyQueueScreen> {
  String selectedType = 'medical_emergency';
  final TextEditingController descriptionController = TextEditingController();
  bool isSubmitting = false;
  List<Map<String, dynamic>> myRequests = [];

  final List<Map<String, dynamic>> types = [
    {
      'name': 'medical_emergency',
      'icon': Icons.local_hospital,
      'color': Colors.red,
      'priority': 1
    },
    {
      'name': 'senior_citizen',
      'icon': Icons.elderly,
      'color': AppColors.warning,
      'priority': 2
    },
    {
      'name': 'person_with_disability',
      'icon': Icons.accessible,
      'color': AppColors.primaryBlue,
      'priority': 2
    },
    {
      'name': 'pregnant_woman',
      'icon': Icons.pregnant_woman,
      'color': AppColors.accentTeal,
      'priority': 2
    },
    {
      'name': 'urgent_document_need',
      'icon': Icons.description,
      'color': AppColors.info,
      'priority': 3
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('emergency_requests');
    if (data != null && data.isNotEmpty) {
      // Parse and load
    }
  }

  Future<void> _submitRequest() async {
    if (descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('describe_requirement'.tr()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'Citizen';

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('request_submitted'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 50),
              const SizedBox(height: 12),
              Text('emergency_received'.tr()),
              const SizedBox(height: 8),
              Text('proceed_to_counter'.tr(args: [userName]),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    }

    setState(() => isSubmitting = false);
    descriptionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('emergency_queue'.tr()),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            tabs: [
              Tab(text: 'request_tab'.tr(), icon: const Icon(Icons.warning_rounded)),
              Tab(text: 'my_requests_tab'.tr(), icon: const Icon(Icons.history)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.warning, Colors.orange]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'emergency_priority_info'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('select_emergency_type'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: types.map((type) {
              final isSelected = selectedType == type['name'];
              return GestureDetector(
                onTap: () => setState(() => selectedType = type['name']),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? type['color'] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: type['color'], width: isSelected ? 0 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(type['icon'],
                          color: isSelected ? Colors.white : type['color'],
                          size: 28),
                      const SizedBox(height: 8),
                      Text(
                        (type['name'] as String).tr(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : type['color'],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('description'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'description_hint'.tr(),
              filled: true,
              fillColor: AppColors.offWhite,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('submit_emergency_request'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.priority_high, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'emergency_misuse_warning'.tr(),
                    style: const TextStyle(fontSize: 11, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 64, color: AppColors.grey),
          const SizedBox(height: 16),
          Text('no_emergency_requests'.tr(),
              style: const TextStyle(color: AppColors.grey)),
          const SizedBox(height: 8),
          Text('submit_to_see_here'.tr(),
              style: const TextStyle(fontSize: 12, color: AppColors.grey)),
        ],
      ),
    );
  }
}
