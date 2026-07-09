import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';

const Map<String, String> _kQueueOfficeKeys = {
  'Divisional Secretariat - Colombo': 'office_divisional_secretariat_colombo',
  'RMV - Werahera': 'office_rmv_werahera',
  'Passport Office - Battaramulla': 'office_passport_battaramulla',
  'Department of Registration': 'office_department_registration',
};

class QueueTabScreen extends StatefulWidget {
  const QueueTabScreen({super.key});

  @override
  State<QueueTabScreen> createState() => _QueueTabScreenState();
}

class _QueueTabScreenState extends State<QueueTabScreen> {
  String selectedOffice = 'Divisional Secretariat - Colombo';
  bool isPriority = false;
  int currentServing = 22;
  int currentToken = 24;
  int waitingAhead = 8;
  int estimatedWait = 35;

  final List<String> offices = [
    'Divisional Secretariat - Colombo',
    'RMV - Werahera',
    'Passport Office - Battaramulla',
    'Department of Registration',
  ];

  final List<Map<String, dynamic>> queueItems = [
    {'token': 'A-025', 'status': 'serving', 'time': '10:30 AM', 'estimated': 0},
    {'token': 'A-026', 'status': 'next', 'time': '10:35 AM', 'estimated': 5},
    {'token': 'A-027', 'status': 'waiting', 'time': '10:40 AM', 'estimated': 10},
    {'token': 'A-028', 'status': 'waiting', 'time': '10:45 AM', 'estimated': 15},
    {'token': 'A-029', 'status': 'waiting', 'time': '10:50 AM', 'estimated': 20},
    {'token': 'A-030', 'status': 'waiting', 'time': '10:55 AM', 'estimated': 25},
    {'token': 'A-031', 'status': 'waiting', 'time': '11:00 AM', 'estimated': 30},
    {'token': 'A-032', 'status': 'waiting', 'time': '11:05 AM', 'estimated': 35},
  ];

  String get currentTime {
    return DateFormat('hh:mm a').format(DateTime.now());
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
                  onChanged: (value) => setState(() => selectedOffice = value!),
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
                                'A-$currentServing',
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
                                'A-$currentToken',
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
                    value: currentServing / currentToken,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('token_number_label'.tr(args: ['$currentServing']), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                      Text('token_number_label'.tr(args: ['$currentToken']), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
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
                      setState(() => isPriority = val);
                      if (val) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('priority_request_submitted_short'.tr()),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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
                    onPressed: () => setState(() {}),
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
                  'people_ahead_count'.tr(args: ['${queueItems.length}']),
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

                final isCurrentUser = item['token'] == 'A-$currentToken';

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