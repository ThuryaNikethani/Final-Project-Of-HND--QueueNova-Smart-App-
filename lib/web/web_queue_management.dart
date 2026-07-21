import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:easy_localization/easy_localization.dart';
import 'web_components/modern_ui_components.dart';
import 'web_api_service.dart';

class WebQueueManagement extends StatefulWidget {
  const WebQueueManagement({super.key});

  @override
  State<WebQueueManagement> createState() => _WebQueueManagementState();
}

class _WebQueueManagementState extends State<WebQueueManagement> {
  int currentServing = 0;
  int totalInQueue = 0;
  int avgWaitTime = 0;
  String crowdLevel = 'Low';
  String selectedOffice = 'Divisional Secretariat - Colombo';

  final List<String> offices = [
    'Divisional Secretariat - Colombo',
    'Divisional Secretariat - Nugegoda',
    'Divisional Secretariat - Kandy',
    'Divisional Secretariat - Galle',
    'Divisional Secretariat - Kurunegala',
    'RMV - Werahera',
    'RMV - Kiribathgoda',
    'RMV - Kandy',
    'Passport Office - Battaramulla',
    'Passport Office - Kandy',
    'Department of Registration - Colombo',
    'NIC Service Center - Colombo',
    'NIC Service Center - Kandy',
    'Immigration Department - Battaramulla',
    'Land Registry Office - Colombo',
    'Land Registry Office - Kandy',
    'Municipal Council - Colombo',
    'Municipal Council - Kandy',
    'Registrar General Department - Colombo',
  ];

  List<Map<String, dynamic>> queueList = [];

  // Tokens already called (Call Next) but not yet marked Complete — kept
  // visible/actionable here instead of just vanishing once called.
  List<Map<String, dynamic>> servingList = [];

  List<Map<String, dynamic>> emergencyQueue = [];

  // Queue Settings → "Enable Emergency Queue": when off, emergency handling
  // is unavailable here regardless of whether entries exist.
  bool _enableEmergencyQueue = true;

  socket_io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadQueueFromApi();
    _loadQueueSettings();
    // Refreshes Queue Settings (e.g. Enable Emergency Queue) as soon as an
    // admin saves a change on Web System Settings, without needing to
    // navigate away and back — same live pattern web_reception.dart already
    // uses for appointment/queue updates.
    _socket = socket_io.io(
      WebApiService.apiOrigin,
      socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket!.on('settings_updated', (_) => _loadQueueSettings());
    // Picks up a payment confirmed elsewhere (e.g. the Appointments screen)
    // after this citizen was already checked into the queue, so this table
    // doesn't keep showing "Pending" once it's actually been paid.
    _socket!.on('queue_update', (_) => _loadQueueFromApi());
    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _loadQueueSettings() async {
    final res = await WebApiService.getSystemSettings();
    final settings = res?['settings'] as Map<String, dynamic>?;
    if (!mounted || settings == null) return;
    setState(() {
      _enableEmergencyQueue = settings['enableEmergencyQueue'] as bool? ?? _enableEmergencyQueue;
    });
  }

  Future<void> _loadQueueFromApi() async {
    final rows = await WebApiService.getQueue(selectedOffice);
    final serving = await WebApiService.getServingQueue(selectedOffice);
    final emergency = await WebApiService.getEmergencyQueue(selectedOffice);
    final stats = await WebApiService.getQueueStats(selectedOffice);
    if (!mounted) return;
    if (stats != null) {
      setState(() {
        final servingToken = stats['currentServingToken'] as String?;
        if (servingToken != null) {
          currentServing = int.tryParse(servingToken.split('-').last) ?? currentServing;
        }
        final avgWait = stats['avgWaitMinutes'];
        if (avgWait is num) avgWaitTime = avgWait.round();
        crowdLevel = stats['crowdLevel'] as String? ?? crowdLevel;
      });
    }
    if (rows.isNotEmpty) {
      setState(() {
        queueList = rows.map((r) => {
          'token': r['token'] ?? '',
          'citizen': r['citizen_name'] ?? '',
          'citizen_nic': r['citizen_nic'],
          'service': r['service'] ?? '',
          'status': r['status'] ?? 'waiting',
          'waitTime': r['wait_time'] ?? '-- min',
          'isPriority': r['is_priority'] == true || r['is_priority'] == 1,
          'counter': r['counter'] ?? 1,
          'paymentStatus': r['payment_status'] ?? 'pending',
          'fee': double.tryParse(r['fee']?.toString() ?? '') ?? 0.0,
          'id': r['id'],
        }).toList();
        totalInQueue = queueList.length;
      });
    }
    if (serving.isNotEmpty) {
      setState(() {
        servingList = serving.map((r) => {
          'token': r['token'] ?? '',
          'citizen': r['citizen_name'] ?? '',
          'citizen_nic': r['citizen_nic'],
          'service': r['service'] ?? '',
          'status': r['status'] ?? 'serving',
          'waitTime': r['wait_time'] ?? '-- min',
          'isPriority': r['is_priority'] == true || r['is_priority'] == 1,
          'counter': r['counter'] ?? 1,
          'paymentStatus': r['payment_status'] ?? 'pending',
          'fee': double.tryParse(r['fee']?.toString() ?? '') ?? 0.0,
          'id': r['id'],
        }).toList();
      });
    }
    if (emergency.isNotEmpty) {
      setState(() {
        emergencyQueue = emergency.map((e) => {
          'token': e['token'] ?? '',
          'citizen': e['citizen_name'] ?? '',
          'citizen_nic': e['citizen_nic'],
          'service': e['reason'] ?? '',
          'status': e['status'] ?? 'priority',
          'waitTime': '-- min',
          'paymentStatus': e['payment_status'] ?? 'paid',
          'id': e['id'],
        }).toList();
      });
    }
  }

  Color getPaymentColor(String paymentStatus) {
    return paymentStatus == 'paid' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
  }

  /// Notifies the citizen identified by [nic] via the `notifications`
  /// collection (the same one the citizen app's Notifications screen reads
  /// live). Looks the uid up through `nic_index`, same as login does.
  Future<void> _notifyCitizenByNic({
    required String? nic,
    required String title,
    required String message,
  }) async {
    if (nic == null || nic.isEmpty) return;
    try {
      final indexDoc = await FirebaseFirestore.instance.collection('nic_index').doc(nic.toUpperCase()).get();
      final uid = indexDoc.data()?['uid'] as String?;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('notifications').add({
        'uid': uid,
        'title': title,
        'message': message,
        'type': 'queue',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyCitizenByNic error: $e');
    }
  }

  void _callNextToken() {
    if (queueList.isEmpty) return;
    final nextToken = queueList.first;

    if (nextToken['paymentStatus'] == 'pending') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('web_payment_required'.tr()),
          content: Text('web_payment_pending_message'.tr(args: ['${nextToken['fee']}', '${nextToken['citizen']}'])),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('ok'.tr()))],
        ),
      );
      return;
    }

    // Optimistic UI — moves the called token into the "Currently Serving"
    // list instead of just removing it, so it stays visible/actionable.
    setState(() {
      currentServing = int.tryParse(nextToken['token'].toString().split('-').last) ?? currentServing;
      queueList.removeAt(0);
      servingList.add({...nextToken, 'status': 'serving'});
      totalInQueue--;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('web_token_called_message'.tr(args: ['${nextToken['token']}', '${nextToken['counter']}'])),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Persist to backend
    WebApiService.callNext(selectedOffice, 'Queue Officer');

    _notifyCitizenByNic(
      nic: nextToken['citizen_nic'] as String?,
      title: 'Your Token is Called',
      message: 'Token ${nextToken['token']} is now being served at Counter ${nextToken['counter']}. Please proceed.',
    );
  }

  void _completeService(Map<String, dynamic> token) {
    // Optimistic UI. totalInQueue only counts the waiting list, so it's
    // only decremented if the token actually came from there — a token
    // completed from servingList was already excluded from that count back
    // when it was called.
    setState(() {
      if (queueList.remove(token)) totalInQueue--;
      servingList.remove(token);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('web_service_completed_message'.tr()), backgroundColor: Colors.blue),
    );

    // Persist to backend
    WebApiService.completeService(token['token'].toString(), 'Service Officer');
  }

  void _sendNotification(Map<String, dynamic> token) {
    _notifyCitizenByNic(
      nic: token['citizen_nic'] as String?,
      title: 'Queue Update',
      message: 'Your token ${token['token']} is coming up soon at Counter ${token['counter']}. Please be ready.',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('web_notification_sent_message'.tr(args: ['${token['citizen']}', '${token['token']}'])),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _reassignCounter(Map<String, dynamic> token) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('web_reassign_counter'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('web_token_label'.tr(args: ['${token['token']}'])),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: token['counter'] as int? ?? 1,
              decoration: InputDecoration(labelText: 'web_select_counter'.tr()),
              items: [1, 2, 3, 4]
                  .map((n) => DropdownMenuItem(value: n, child: Text('web_counter_n'.tr(args: ['$n']))))
                  .toList(),
              onChanged: (value) {
                final newCounter = value ?? 1;
                setState(() => token['counter'] = newCounter);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('web_token_reassigned_message'.tr(args: ['${token['token']}', '$newCounter'])), backgroundColor: Colors.green),
                );
                // Persist to backend
                WebApiService.reassignCounter(token['token'].toString(), newCounter, 'Queue Officer');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _processEmergencyQueue() {
    if (emergencyQueue.isEmpty) return;
    final emergencyToken = emergencyQueue.first;

    if (emergencyToken['paymentStatus'] == 'pending') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('web_payment_required'.tr()),
          content: Text('web_emergency_payment_pending'.tr()),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('ok'.tr()))],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('web_emergency_priority_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('web_token_label'.tr(args: ['${emergencyToken['token']}'])),
            Text('web_citizen_label'.tr(args: ['${emergencyToken['citizen']}'])),
            Text('web_reason_label'.tr(args: ['${emergencyToken['service']}'])),
            const SizedBox(height: 16),
            Text('web_priority_process_confirm'.tr()),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('web_later'.tr())),
          ElevatedButton(
            onPressed: () {
              final tokenStr = emergencyToken['token'].toString();
              setState(() {
                emergencyQueue.removeAt(0);
                currentServing = int.tryParse(tokenStr.split('-').last) ?? currentServing;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('web_emergency_called_message'.tr()), backgroundColor: Colors.red),
              );
              // Persist to backend
              WebApiService.processEmergency(tokenStr, 'Queue Officer');

              _notifyCitizenByNic(
                nic: emergencyToken['citizen_nic'] as String?,
                title: 'Priority Token Called',
                message: 'Your priority token $tokenStr is now being processed immediately.',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('web_process_now'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('web_menu_queue_management'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ModernBackground(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              ModernPageHeader(
                title: 'web_menu_queue_management'.tr(),
                subtitle: 'web_queue_mgmt_subtitle'.tr(),
                icon: Icons.queue,
                actions: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                        const SizedBox(width: 6),
                        Text('web_system_active'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stats Row - Clean stat cards without overflow
              SizedBox(
                height: 100,
                child: Row(
                  children: [
                    _buildStatCard('web_stat_currently_serving'.tr(), 'A-$currentServing', Icons.person_outline, const Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    _buildStatCard('web_stat_total_in_queue'.tr(), '$totalInQueue', Icons.queue, const Color(0xFF1A56DB)),
                    const SizedBox(width: 12),
                    _buildStatCard('web_stat_avg_wait_time'.tr(), '$avgWaitTime min', Icons.timer_outlined, const Color(0xFFF59E0B)),
                    const SizedBox(width: 12),
                    _buildStatCard('web_stat_crowd_level'.tr(), _crowdLevelLabel(), Icons.people_outline, _getCrowdColor()),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Office Selector and Actions
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedOffice,
                          isExpanded: true,
                          items: offices.map((office) {
                            return DropdownMenuItem(value: office, child: Text(office));
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedOffice = value!);
                            _loadQueueFromApi();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: _callNextToken,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text('web_call_next'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (emergencyQueue.isNotEmpty && _enableEmergencyQueue)
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: _processEmergencyQueue,
                        icon: const Icon(Icons.warning_rounded, size: 18),
                        label: Text('web_emergency_count'.tr(args: ['${emergencyQueue.length}'])),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Emergency Queue Alert
              if (emergencyQueue.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Text(
                        'web_urgent_requests_alert'.tr(args: ['${emergencyQueue.length}']),
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (emergencyQueue.isNotEmpty) const SizedBox(height: 12),

              // Currently Serving — tokens already called (Call Next) but
              // not yet marked Complete, so a called token stays visible
              // and actionable instead of just disappearing.
              if (servingList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Currently Serving',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${servingList.length} being served',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: servingList.map((item) => _buildServingCard(item)).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Queue List Header
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'web_current_queue'.tr(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56DB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('web_count_waiting'.tr(args: ['${queueList.length}']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A56DB))),
                    ),
                  ],
                ),
              ),

              // Queue List Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 14,
                        dataRowHeight: 48,
                        headingRowHeight: 40,
                        columns: [
                          DataColumn(label: Text('web_col_token'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('web_col_citizen'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('web_col_service'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('web_col_wait_time'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('web_col_payment'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('web_col_priority'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('web_col_counter'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          DataColumn(label: Text('web_col_actions'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                        ],
                        rows: queueList.map((item) {
                          final paymentColor = getPaymentColor(item['paymentStatus']);
                          return DataRow(
                            color: MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.hovered)) {
                                  return const Color(0xFF1A56DB).withOpacity(0.05);
                                }
                                return null;
                              },
                            ),
                            cells: [
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A56DB).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(item['token'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF1A56DB))),
                                ),
                              ),
                              DataCell(Text(item['citizen'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11))),
                              DataCell(Text(item['service'], style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Colors.grey.shade700))),
                              DataCell(Text(item['waitTime'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: paymentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item['paymentStatus'] == 'paid' ? Icons.check_circle : Icons.pending,
                                        size: 11,
                                        color: paymentColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        item['paymentStatus'] == 'paid' ? 'web_paid'.tr() : 'pending'.tr(),
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: paymentColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item['isPriority'] ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item['isPriority'] ? 'web_yes'.tr() : 'no_button'.tr(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                      color: item['isPriority'] ? Colors.red : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('C${item['counter']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF7C3AED))),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'web_tooltip_send_notification'.tr(),
                                      child: IconButton(
                                        icon: const Icon(Icons.notifications_outlined),
                                        onPressed: () => _sendNotification(item),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.orange.withOpacity(0.1),
                                          foregroundColor: Colors.orange,
                                        ),
                                        iconSize: 14,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'web_reassign_counter'.tr(),
                                      child: IconButton(
                                        icon: const Icon(Icons.swap_horiz_rounded),
                                        onPressed: () => _reassignCounter(item),
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFF1A56DB).withOpacity(0.1),
                                          foregroundColor: const Color(0xFF1A56DB),
                                        ),
                                        iconSize: 14,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'web_tooltip_complete_service'.tr(),
                                      child: IconButton(
                                        icon: const Icon(Icons.check_circle_outline),
                                        onPressed: () => _completeService(item),
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                                          foregroundColor: const Color(0xFF10B981),
                                        ),
                                        iconSize: 14,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServingCard(Map<String, dynamic> item) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(item['token'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF10B981))),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('C${item['counter']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF7C3AED))),
              ),
              const Spacer(),
              Tooltip(
                message: 'web_tooltip_send_notification'.tr(),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _sendNotification(item),
                  style: IconButton.styleFrom(backgroundColor: Colors.orange.withOpacity(0.1), foregroundColor: Colors.orange),
                  iconSize: 14,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
              ),
              Tooltip(
                message: 'web_reassign_counter'.tr(),
                child: IconButton(
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: () => _reassignCounter(item),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF1A56DB).withOpacity(0.1), foregroundColor: const Color(0xFF1A56DB)),
                  iconSize: 14,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
              ),
              Tooltip(
                message: 'web_tooltip_complete_service'.tr(),
                child: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () => _completeService(item),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981).withOpacity(0.1), foregroundColor: const Color(0xFF10B981)),
                  iconSize: 14,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item['citizen'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(item['service'], style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _crowdLevelLabel() {
    switch (crowdLevel) {
      case 'Low':
        return 'web_crowd_low'.tr();
      case 'Medium':
        return 'web_crowd_medium'.tr();
      case 'High':
        return 'web_crowd_high'.tr();
      default:
        return crowdLevel;
    }
  }

  Color _getCrowdColor() {
    switch (crowdLevel) {
      case 'Low':
        return const Color(0xFF10B981);
      case 'Medium':
        return const Color(0xFFF59E0B);
      case 'High':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }
}