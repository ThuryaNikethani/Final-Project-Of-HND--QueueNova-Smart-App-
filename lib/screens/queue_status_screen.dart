import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide DateFormat;
import 'package:intl/intl.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/ml_prediction_service.dart';

class QueueStatusScreen extends StatefulWidget {
  const QueueStatusScreen({super.key});

  @override
  State<QueueStatusScreen> createState() => _QueueStatusScreenState();
}

class _QueueStatusScreenState extends State<QueueStatusScreen> {
  int currentToken = 24;
  int waitingAhead = 8;
  int estimatedWait = 35;
  String status = 'Waiting';
  bool isPriority = false;
  
  String selectedOffice = 'Divisional Secretariat - Colombo';
  bool isOfficeOpen = true;
  String officeStatusMessage = '';
  String nextOpenTime = '';
  String currentTime = '';
  
  final List<String> offices = [
    'Divisional Secretariat - Colombo',
    'Divisional Secretariat - Kandy',
    'Divisional Secretariat - Galle',
    'RMV - Werahera',
    'RMV - Kiribathgoda',
    'Passport Office - Battaramulla',
    'Department of Registration - Colombo',
    'NIC Service Center - Colombo',
    'Immigration Department - Battaramulla',
  ];
  
  final Map<String, Map<String, dynamic>> officeHours = {
    'Divisional Secretariat - Colombo': {
      'weekdays': {'open': '08:30', 'close': '16:30'},
      'saturday': {'open': '09:00', 'close': '13:00'},
      'sunday': {'open': 'Closed', 'close': 'Closed'},
    },
    'Divisional Secretariat - Kandy': {
      'weekdays': {'open': '08:30', 'close': '16:30'},
      'saturday': {'open': '09:00', 'close': '13:00'},
      'sunday': {'open': 'Closed', 'close': 'Closed'},
    },
    'Divisional Secretariat - Galle': {
      'weekdays': {'open': '08:30', 'close': '16:30'},
      'saturday': {'open': '09:00', 'close': '13:00'},
      'sunday': {'open': 'Closed', 'close': 'Closed'},
    },
    'RMV - Werahera': {
      'weekdays': {'open': '08:00', 'close': '17:00'},
      'saturday': {'open': '09:00', 'close': '15:00'},
      'sunday': {'open': 'Closed', 'close': 'Closed'},
    },
    'RMV - Kiribathgoda': {
      'weekdays': {'open': '08:00', 'close': '17:00'},
      'saturday': {'open': '09:00', 'close': '15:00'},
      'sunday': {'open': 'Closed', 'close': 'Closed'},
    },
    'Passport Office - Battaramulla': {
      'weekdays': {'open': '09:00', 'close': '15:30'},
      'saturday': {'open': 'Closed', 'close': 'Closed'},
      'sunday': {'open': 'Closed', 'close': 'Closed'},
    },
    'Department of Registration - Colombo': {
      'weekdays': {'open': '08:30', 'close': '16:00'},
      'saturday': {'open': 'Closed', 'close': 'Closed'},
      'sunday': {'open': 'Closed', 'close': 'Closed'},
    },
    'NIC Service Center - Colombo': {
      'weekdays': {'open': '08:30', 'close': '16:30'},
      'saturday': {'open': '09:00', 'close': '13:00'},
      'sunday': {'open': 'Closed', 'close': 'Closed'},
    },
    'Immigration Department - Battaramulla': {
      'weekdays': {'open': '09:00', 'close': '16:00'},
      'saturday': {'open': 'Closed', 'close': 'Closed'},
      'sunday': {'open': 'Closed', 'close': 'Closed'},
    },
  };

  final List<Map<String, dynamic>> queueList = [
    {'token': 'A-025', 'status': 'serving', 'time': '10:30 AM'},
    {'token': 'A-026', 'status': 'next', 'time': '10:35 AM'},
    {'token': 'A-027', 'status': 'waiting', 'time': '10:40 AM'},
    {'token': 'A-028', 'status': 'waiting', 'time': '10:45 AM'},
    {'token': 'A-029', 'status': 'waiting', 'time': '10:50 AM'},
    {'token': 'A-030', 'status': 'waiting', 'time': '10:55 AM'},
    {'token': 'A-031', 'status': 'waiting', 'time': '11:00 AM'},
  ];

  int _timerTick = 0;

  @override
  void initState() {
    super.initState();
    _updateOfficeStatus();
    _updateMLPrediction();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _timerTick++;
        _updateOfficeStatus();
        // Refresh ML prediction every 60 seconds
        if (_timerTick % 60 == 0) _updateMLPrediction();
        _startTimer();
      }
    });
  }

  void _updateMLPrediction() {
    final prediction = MLPredictionService.predict(
      officeName: selectedOffice,
    );
    if (mounted) {
      setState(() {
        waitingAhead = prediction.waitingAhead;
        estimatedWait = prediction.estimatedWaitMinutes;
      });
    }
  }

  void _updateOfficeStatus() {
    final now = DateTime.now();
    currentTime = DateFormat('hh:mm a').format(now);
    
    final hours = officeHours[selectedOffice];
    if (hours == null) return;
    
    final weekday = now.weekday;
    Map<String, String> todayHours;
    
    if (weekday == 7) {
      todayHours = hours['sunday'];
    } else if (weekday == 6) {
      todayHours = hours['saturday'];
    } else {
      todayHours = hours['weekdays'];
    }
    
    if (todayHours['open'] == 'Closed') {
      setState(() {
        isOfficeOpen = false;
        officeStatusMessage = 'closed_today'.tr();
        nextOpenTime = _getNextOpenTime(weekday, hours);
      });
      return;
    }

    final openTime = _parseTime(todayHours['open']!);
    final closeTime = _parseTime(todayHours['close']!);

    if (now.isAfter(openTime) && now.isBefore(closeTime)) {
      final minutesToClose = closeTime.difference(now).inMinutes;
      setState(() {
        isOfficeOpen = true;
        officeStatusMessage = 'open_closes_in'.tr(args: ['$minutesToClose']);
        nextOpenTime = 'open_until_time'.tr(args: [todayHours['close']!]);
      });
    } else if (now.isBefore(openTime)) {
      final minutesToOpen = openTime.difference(now).inMinutes;
      setState(() {
        isOfficeOpen = false;
        officeStatusMessage = 'opens_in_minutes'.tr(args: ['$minutesToOpen']);
        nextOpenTime = 'opens_at_time'.tr(args: [todayHours['open']!]);
      });
    } else {
      setState(() {
        isOfficeOpen = false;
        officeStatusMessage = 'closed_for_today'.tr();
        nextOpenTime = _getNextOpenTime(weekday, hours);
      });
    }
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  String _getNextOpenTime(int currentWeekday, Map<String, dynamic> hours) {
    for (int i = 1; i <= 7; i++) {
      int checkDay = currentWeekday + i;
      if (checkDay > 7) checkDay = checkDay - 7;
      
      Map<String, String> dayHours;
      if (checkDay == 7) {
        dayHours = hours['sunday'];
      } else if (checkDay == 6) {
        dayHours = hours['saturday'];
      } else {
        dayHours = hours['weekdays'];
      }
      
      if (dayHours['open'] != 'Closed') {
        final dayName = _getDayName(checkDay);
        return 'next_open_display'.tr(args: ['$dayName ${dayHours['open']}']);
      }
    }
    return 'contact_office'.tr();
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    return DropdownMenuItem(value: office, child: Text(office));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedOffice = value!);
                    _updateOfficeStatus();
                    _updateMLPrediction();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOfficeOpen ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isOfficeOpen ? AppColors.success : AppColors.error),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(isOfficeOpen ? Icons.check_circle : Icons.cancel, color: isOfficeOpen ? AppColors.success : AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(officeStatusMessage, style: TextStyle(fontWeight: FontWeight.bold, color: isOfficeOpen ? AppColors.success : AppColors.error)),
                            const SizedBox(height: 4),
                            Text('current_time_display'.tr(args: [currentTime]), style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        Text('next_open_display'.tr(args: [nextOpenTime]), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            if (isOfficeOpen) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    Text('your_current_token'.tr(), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Text('A-$currentToken', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoChip('$waitingAhead ${'ahead'.tr()}', Icons.queue, Colors.white70),
                        _buildInfoChip('$estimatedWait min', Icons.timer, Colors.white70),
                        _buildInfoChip(status, Icons.info, status == 'Waiting' ? Colors.orange : Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    const Icon(Icons.priority_high, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(child: Text('request_priority_queue'.tr())),
                    Switch(
                      value: isPriority,
                      onChanged: (val) {
                        setState(() => isPriority = val);
                        if (val) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('priority_request_submitted'.tr()), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                      activeColor: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Text('queue_list'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: queueList.length,
                itemBuilder: (context, index) {
                  final item = queueList[index];
                  Color statusColor = item['status'] == 'serving' ? AppColors.success : (item['status'] == 'next' ? AppColors.warning : AppColors.grey);
                  String statusText = item['status'] == 'serving' ? 'serving'.tr() : (item['status'] == 'next' ? 'next'.tr() : 'waiting'.tr());
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item['token'] == 'A-$currentToken' ? AppColors.lightBlue : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.greyLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Center(child: Text(item['token'], style: TextStyle(fontWeight: FontWeight.bold, color: statusColor))),
                        ),
                        const SizedBox(width: 15),
                        Expanded(child: Text(item['time'])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text(statusText, style: TextStyle(color: statusColor)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    const Icon(Icons.business, size: 60, color: AppColors.error),
                    const SizedBox(height: 15),
                    Text('office_closed_now'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(officeStatusMessage, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          Text('next_open_display'.tr(args: [nextOpenTime])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}