import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/queue_status_service.dart';
import 'package:queuenova_mobile/services/ml_prediction_service.dart';
import 'package:queuenova_mobile/services/appointment_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

const Map<String, String> _kQueueOfficeKeys = {
  'Divisional Secretariat - Colombo': 'office_divisional_secretariat_colombo',
  'Divisional Secretariat - Kandy': 'office_divisional_secretariat_kandy',
  'Divisional Secretariat - Galle': 'office_ds_galle',
  'Divisional Secretariat - Kurunegala': 'office_ds_kurunegala',
  'RMV - Werahera': 'office_rmv_werahera',
  'RMV - Kiribathgoda': 'office_rmv_kiribathgoda',
  'RMV - Kandy': 'office_rmv_kandy',
  'Passport Office - Battaramulla': 'office_passport_battaramulla',
  'Passport Office - Kandy': 'office_passport_kandy',
  'Department of Registration - Colombo': 'office_dept_registration_colombo',
  'NIC Service Center - Colombo': 'office_nic_center_colombo',
  'NIC Service Center - Kandy': 'office_nic_center_kandy',
  'Immigration Department - Battaramulla': 'office_immigration_battaramulla',
  'Land Registry Office - Colombo': 'office_land_registry_colombo',
  'Land Registry Office - Kandy': 'office_land_registry_kandy',
  'Municipal Council - Colombo': 'office_municipal_council_colombo',
  'Municipal Council - Kandy': 'office_municipal_council_kandy',
  'Registrar General Department - Colombo': 'office_registrar_general_colombo',
};

class QueueTabScreen extends StatefulWidget {
  const QueueTabScreen({super.key});

  @override
  State<QueueTabScreen> createState() => _QueueTabScreenState();
}

class _QueueTabScreenState extends State<QueueTabScreen> {
  // Survives this screen's State being torn down/recreated when the bottom
  // nav swaps tabs (HomeScreen swaps `body:` directly, no IndexedStack), so
  // a manual office pick isn't clobbered by auto-detection on revisit.
  static String? _persistedSelectedOffice;
  static bool _userSelectedManually = false;

  String selectedOffice = _persistedSelectedOffice ?? 'Divisional Secretariat - Colombo';
  bool isPriority = false;
  String currentServing = '--';
  String currentToken = '--';
  int waitingAhead = 0;
  int estimatedWait = 0;
  bool _loading = true;
  DateTime _lastUpdated = DateTime.now();

  final List<String> offices = _kQueueOfficeKeys.keys.toList();

  List<Map<String, dynamic>> queueItems = [];

  String? _myNic;
  String? _myName;
  String? _myService;
  socket_io.Socket? _socket;
  Timer? _refreshTimer;
  bool _initialLoad = true;
  int _loadRequestId = 0;

  String get currentTime {
    return DateFormat('hh:mm a').format(_lastUpdated);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _myNic = prefs.getString('userNIC');
    _myName = prefs.getString('userName');
    await _loadQueueData();
    _socket = QueueStatusService.connect(onQueueChanged: _loadQueueData);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadQueueData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  int? _tokenNumber(String? token) {
    if (token == null) return null;
    final digits = token.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  double get _progressValue {
    final servingNum = _tokenNumber(currentServing);
    final myNum = _tokenNumber(currentToken);
    if (servingNum != null && myNum != null && myNum > 0) {
      return (servingNum / myNum).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  Future<String?> _latestUpcomingAppointmentOffice() async {
    final appointments = await AppointmentService.getAppointments();
    final upcoming = appointments
        .where((a) => a.status == 'Confirmed' || a.status == 'Pending')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return upcoming.isNotEmpty ? upcoming.first.office : null;
  }

  Future<void> _loadQueueData() async {
    final requestId = ++_loadRequestId;
    final nic = _myNic ?? '';
    final position = await QueueStatusService.getMyQueuePosition(nic);

    String office = selectedOffice;
    if (_initialLoad && !_userSelectedManually) {
      final myOfficeId = position['officeId'] as String?;
      if (position['found'] == true && myOfficeId != null && offices.contains(myOfficeId)) {
        office = myOfficeId;
      } else {
        final appointmentOffice = await _latestUpcomingAppointmentOffice();
        if (appointmentOffice != null && offices.contains(appointmentOffice)) {
          office = appointmentOffice;
        }
      }
    }
    _initialLoad = false;

    final results = await Future.wait([
      QueueStatusService.getOfficeStats(office),
      QueueStatusService.getWaitingList(office),
      MLPredictionService.fetchAndPredict(officeName: office),
    ]);

    if (!mounted || requestId != _loadRequestId) return;

    final stats = results[0] as Map<String, dynamic>;
    final waitingList = (results[1] as List).cast<Map<String, dynamic>>();
    final prediction = results[2] as QueuePrediction;

    final avgServiceMinutes = (stats['avgWaitMinutes'] as num?)?.toDouble() ?? 8.0;

    final items = <Map<String, dynamic>>[];
    final servingToken = stats['currentServingToken'] as String?;
    if (servingToken != null) {
      items.add({'token': servingToken, 'status': 'serving', 'estimated': 0});
    }
    for (var i = 0; i < waitingList.length; i++) {
      items.add({
        'token': waitingList[i]['token'],
        'status': i == 0 ? 'next' : 'waiting',
        'estimated': ((i + 1) * avgServiceMinutes).round(),
      });
    }

    setState(() {
      selectedOffice = office;
      _persistedSelectedOffice = office;
      currentServing = servingToken ?? '--';
      currentToken = position['found'] == true ? (position['token'] as String? ?? '--') : '--';
      waitingAhead = position['found'] == true ? (position['position'] as num? ?? 0).toInt() : waitingList.length;
      estimatedWait = prediction.estimatedWaitMinutes;
      queueItems = items;
      isPriority = position['found'] == true && position['isPriority'] == true;
      _myService = position['found'] == true ? position['service'] as String? : null;
      _lastUpdated = DateTime.now();
      _loading = false;
    });
  }

  /// Sends a priority-queue request to staff via the same `staff_notifications`
  /// collection the officer dashboard already reads. Approval flips
  /// `is_priority` on this citizen's queue entry — see `web_notifications.dart`
  /// `_resolvePriorityRequest`. Requires an active waiting token.
  Future<void> _requestPriorityQueue() async {
    if (currentToken == '--') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('priority_no_active_token'.tr()), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final name = _myName?.isNotEmpty == true ? _myName! : 'A citizen';
    final service = _myService ?? '';
    bool sent = true;
    try {
      await FirebaseFirestore.instance.collection('staff_notifications').add({
        'title': 'Priority Queue Request',
        'message': '$name (token $currentToken, $service) requests priority queue access at $selectedOffice.',
        'type': 'priority_request',
        'action': 'Approve',
        'targetRoles': const ['queueManager'],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'token': currentToken,
        'officeId': selectedOffice,
        'nic': _myNic,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      sent = false;
    }
    if (!mounted) return;
    if (sent) {
      setState(() => isPriority = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('priority_request_submitted_short'.tr()), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('priority_request_failed'.tr()), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('queue_status'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Office Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedOffice,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                  items: offices.map((office) {
                    return DropdownMenuItem(value: office, child: Text(_kQueueOfficeKeys[office]!.tr()));
                  }).toList(),
                  onChanged: (value) {
                    _userSelectedManually = true;
                    setState(() => selectedOffice = value!);
                    _loadQueueData();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Queue Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('currently_serving_label'.tr(),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                currentServing,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('your_token_label'.tr(),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                currentToken,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('est_wait_label'.tr(),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'estimated_wait_min_suffix'.tr(args: ['$estimatedWait']),
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: _progressValue,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('token_number_label'.tr(args: [currentServing]), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                      Text('token_number_label'.tr(args: [currentToken]), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Priority Queue Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.priority_high, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'request_priority_queue_short'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'priority_categories_short'.tr(),
                    style: TextStyle(fontSize: 11, color: AppColors.grey),
                  ),
                  Switch(
                    value: isPriority,
                    onChanged: (val) {
                      if (val) {
                        _requestPriorityQueue();
                      } else {
                        setState(() => isPriority = false);
                      }
                    },
                    activeColor: AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Queue Updates Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'live_updates_interval'.tr(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    'last_updated_time'.tr(args: [currentTime]),
                    style: TextStyle(fontSize: 11, color: AppColors.grey),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _loading ? null : _loadQueueData,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Queue List Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'queue_line_title'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'people_ahead_count'.tr(args: ['$waitingAhead']),
                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Queue List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: queueItems.length,
              itemBuilder: (context, index) {
                final item = queueItems[index];
                Color statusColor;
                String statusText;

                if (item['status'] == 'serving') {
                  statusColor = AppColors.success;
                  statusText = 'serving_now_status'.tr();
                } else if (item['status'] == 'next') {
                  statusColor = AppColors.warning;
                  statusText = 'you_are_next_status'.tr();
                } else {
                  statusColor = AppColors.grey;
                  statusText = 'waiting'.tr();
                }

                final isCurrentUser = item['token'] == currentToken;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentUser ? AppColors.lightBlue : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentUser ? AppColors.primaryBlue : AppColors.greyLight,
                      width: isCurrentUser ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            item['token'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['status'] == 'serving' ? 'currently_serving_label'.tr() :
                              item['status'] == 'next' ? 'next_in_line_status'.tr() : 'in_queue_status'.tr(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'estimated_label'.tr(args: ['minutes_suffix'.tr(args: ['${item['estimated']}'])]),
                              style: TextStyle(fontSize: 11, color: AppColors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isCurrentUser)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.person, size: 16, color: AppColors.primaryBlue),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Info Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'keep_token_ready_note'.tr(),
                      style: TextStyle(fontSize: 11, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}