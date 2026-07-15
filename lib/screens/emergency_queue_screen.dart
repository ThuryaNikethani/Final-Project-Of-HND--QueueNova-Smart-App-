import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide DateFormat;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:queuenova_mobile/services/queue_status_service.dart';

class EmergencyQueueScreen extends StatefulWidget {
  const EmergencyQueueScreen({super.key});

  @override
  State<EmergencyQueueScreen> createState() => _EmergencyQueueScreenState();
}

class _EmergencyQueueScreenState extends State<EmergencyQueueScreen> {
  String selectedType = 'medical_emergency';
  final TextEditingController descriptionController = TextEditingController();
  bool isSubmitting = false;

  String? _myNic;
  String? _myName;
  String? _myToken;
  String? _myOfficeId;
  bool _loadingPosition = true;

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
    _loadMyQueuePosition();
  }

  Future<void> _loadMyQueuePosition() async {
    final prefs = await SharedPreferences.getInstance();
    _myNic = prefs.getString('userNIC');
    _myName = prefs.getString('userName');
    final position = await QueueStatusService.getMyQueuePosition(_myNic ?? '');
    if (!mounted) return;
    setState(() {
      _myToken = position['found'] == true ? position['token'] as String? : null;
      _myOfficeId = position['found'] == true ? position['officeId'] as String? : null;
      _loadingPosition = false;
    });
  }

  /// Sends the emergency request to staff via the same `staff_notifications`
  /// mechanism `queue_tab_screen.dart`'s priority-queue toggle already uses
  /// (staff resolve it from `web_notifications.dart` `_resolvePriorityRequest`,
  /// which flips `is_priority` on this citizen's queue entry). Requires an
  /// active waiting token for the same reason: there's no queue entry to
  /// prioritise otherwise.
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

    if (_myToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('priority_no_active_token'.tr()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => isSubmitting = true);

    final name = _myName?.isNotEmpty == true ? _myName! : 'A citizen';
    final typeLabel = selectedType.tr();
    bool sent = true;
    try {
      await FirebaseFirestore.instance.collection('staff_notifications').add({
        'title': 'Emergency Queue Request',
        'message':
            '$name (token $_myToken) requests emergency priority access at $_myOfficeId: $typeLabel — ${descriptionController.text}',
        'type': 'priority_request',
        'action': 'Approve',
        'targetRoles': const ['queueManager'],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'token': _myToken,
        'officeId': _myOfficeId,
        'nic': _myNic,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      sent = false;
    }

    if (!mounted) return;
    setState(() => isSubmitting = false);

    if (sent) {
      descriptionController.clear();
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
              Text('proceed_to_counter'.tr(args: [name]),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('priority_request_failed'.tr()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating),
      );
    }
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
          if (!_loadingPosition && _myToken == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'priority_no_active_token'.tr(),
                      style: const TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    if (_myNic == null || _myNic!.isEmpty) {
      return _buildEmptyHistory();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('staff_notifications')
          .where('nic', isEqualTo: _myNic)
          .where('type', isEqualTo: 'priority_request')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyHistory();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final dismissedBy = (data['dismissedBy'] as List?) ?? const [];
            final resolved = dismissedBy.isNotEmpty;
            final createdAt = data['createdAt'] as Timestamp?;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.greyLight, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          data['message'] as String? ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (resolved ? AppColors.success : AppColors.warning).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          resolved ? 'completed_status'.tr() : 'pending'.tr(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: resolved ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate()),
                      style: TextStyle(fontSize: 10, color: AppColors.grey),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyHistory() {
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
