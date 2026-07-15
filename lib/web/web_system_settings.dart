import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebSystemSettings extends StatefulWidget {
  const WebSystemSettings({super.key});

  @override
  State<WebSystemSettings> createState() => _WebSystemSettingsState();
}

class _WebSystemSettingsState extends State<WebSystemSettings> {
  // General Settings
  bool emailNotifications = true;
  bool smsNotifications = true;
  bool pushNotifications = true;
  String defaultLanguage = 'English';
  String dateFormat = 'DD/MM/YYYY';
  String timeZone = 'Asia/Colombo';

  // Department Settings
  List<Map<String, dynamic>> departments = [
    {'name': 'Divisional Secretariat - Colombo', 'code': 'DSC', 'active': true, 'type': 'Divisional Secretariat'},
    {'name': 'RMV - Werahera', 'code': 'RMV', 'active': true, 'type': 'RMV'},
    {'name': 'Passport Office - Battaramulla', 'code': 'PO', 'active': true, 'type': 'Passport Office'},
    {'name': 'Department of Registration', 'code': 'DOR', 'active': true, 'type': 'Registration'},
    {'name': 'NIC Service Center - Colombo', 'code': 'NIC', 'active': true, 'type': 'NIC Center'},
  ];

  // Queue Settings
  int maxQueuePerCounter = 20;
  int defaultWaitTime = 15;
  bool enableEmergencyQueue = true;
  bool enablePriorityQueue = true;
  int priorityQueueLimit = 5;

  // Office Hours
  TimeOfDay officeOpenTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay officeCloseTime = const TimeOfDay(hour: 16, minute: 30);
  bool saturdayOpen = true;
  bool sundayOpen = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDepartments();
  }

  Future<void> _loadSettings() async {
    final res = await WebApiService.getSystemSettings();
    final settings = res?['settings'] as Map<String, dynamic>?;
    if (!mounted || settings == null || settings.isEmpty) return;
    setState(() {
      emailNotifications = settings['emailNotifications'] as bool? ?? emailNotifications;
      smsNotifications = settings['smsNotifications'] as bool? ?? smsNotifications;
      pushNotifications = settings['pushNotifications'] as bool? ?? pushNotifications;
      defaultLanguage = settings['defaultLanguage'] as String? ?? defaultLanguage;
      dateFormat = settings['dateFormat'] as String? ?? dateFormat;
      timeZone = settings['timeZone'] as String? ?? timeZone;
      maxQueuePerCounter = settings['maxQueuePerCounter'] as int? ?? maxQueuePerCounter;
      defaultWaitTime = settings['defaultWaitTime'] as int? ?? defaultWaitTime;
      enableEmergencyQueue = settings['enableEmergencyQueue'] as bool? ?? enableEmergencyQueue;
      enablePriorityQueue = settings['enablePriorityQueue'] as bool? ?? enablePriorityQueue;
      priorityQueueLimit = settings['priorityQueueLimit'] as int? ?? priorityQueueLimit;
      officeOpenTime = _parseTime(settings['officeOpenTime'] as String?) ?? officeOpenTime;
      officeCloseTime = _parseTime(settings['officeCloseTime'] as String?) ?? officeCloseTime;
      saturdayOpen = settings['saturdayOpen'] as bool? ?? saturdayOpen;
      sundayOpen = settings['sundayOpen'] as bool? ?? sundayOpen;
    });
  }

  Future<void> _loadDepartments() async {
    final apiDepartments = await WebApiService.getDepartments();
    if (!mounted || apiDepartments.isEmpty) return;
    setState(() => departments = apiDepartments);
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _saveAllSettings() async {
    setState(() => _saving = true);
    final success = await WebApiService.saveSystemSettings({
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
      'pushNotifications': pushNotifications,
      'defaultLanguage': defaultLanguage,
      'dateFormat': dateFormat,
      'timeZone': timeZone,
      'maxQueuePerCounter': maxQueuePerCounter,
      'defaultWaitTime': defaultWaitTime,
      'enableEmergencyQueue': enableEmergencyQueue,
      'enablePriorityQueue': enablePriorityQueue,
      'priorityQueueLimit': priorityQueueLimit,
      'officeOpenTime': _formatTime(officeOpenTime),
      'officeCloseTime': _formatTime(officeCloseTime),
      'saturdayOpen': saturdayOpen,
      'sundayOpen': sundayOpen,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'web_all_settings_saved_success'.tr() : 'web_settings_save_failed'.tr()),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _showAddDepartmentDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    String selectedType = 'Divisional Secretariat';
    final List<String> types = ['Divisional Secretariat', 'RMV', 'Passport Office', 'Registration', 'NIC Center', 'Other'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_add_department'.tr()),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'web_department_name'.tr(),
                  prefixIcon: const Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'web_department_code'.tr(),
                  prefixIcon: const Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'web_department_type'.tr(),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: types.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) => selectedType = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text;
              final code = codeController.text;
              final newEntry = {
                'name': name,
                'code': code,
                'active': true,
                'type': selectedType,
              };
              setState(() => departments.add(newEntry));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('web_department_added_success'.tr()), backgroundColor: Colors.green),
              );

              final saved = await WebApiService.addDepartment(name: name, code: code, type: selectedType);
              if (saved != null && mounted) {
                setState(() {
                  final idx = departments.indexOf(newEntry);
                  if (idx != -1) departments[idx] = saved;
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: Text('web_add_department'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('web_menu_system_settings'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // General Settings
            _buildSettingsCard('web_general_settings'.tr(), [
              _buildSwitchTile('web_settings_email_notifications'.tr(), 'web_sys_email_notifications_sub'.tr(), emailNotifications, (v) => setState(() => emailNotifications = v)),
              _buildSwitchTile('web_sms_notifications'.tr(), 'web_sms_notifications_sub'.tr(), smsNotifications, (v) => setState(() => smsNotifications = v)),
              _buildSwitchTile('web_settings_push_notifications'.tr(), 'web_sys_push_notifications_sub'.tr(), pushNotifications, (v) => setState(() => pushNotifications = v)),
              _buildDropdownTile('web_default_language'.tr(), defaultLanguage, ['English', 'Sinhala', 'Tamil'], (v) {
                setState(() => defaultLanguage = v);
                final code = switch (v) {
                  'Sinhala' => 'si',
                  'Tamil' => 'ta',
                  _ => 'en',
                };
                if (context.locale.languageCode != code) {
                  context.setLocale(Locale(code));
                }
              }),
              _buildDropdownTile('web_date_format'.tr(), dateFormat, ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'], (v) => setState(() => dateFormat = v)),
              _buildDropdownTile('web_time_zone'.tr(), timeZone, ['Asia/Colombo', 'Asia/Kolkata', 'UTC'], (v) => setState(() => timeZone = v)),
            ]),
            const SizedBox(height: 20),

            // Department Management
            _buildSettingsCard('web_department_management_title'.tr(), [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showAddDepartmentDialog,
                    icon: const Icon(Icons.add),
                    label: Text('web_add_department'.tr()),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('web_department_name'.tr())),
                    DataColumn(label: Text('web_col_code'.tr())),
                    DataColumn(label: Text('web_col_type'.tr())),
                    DataColumn(label: Text('web_col_status'.tr())),
                    DataColumn(label: Text('web_col_actions'.tr())),
                  ],
                  rows: departments.map((dept) {
                    return DataRow(cells: [
                      DataCell(Text(dept['name'])),
                      DataCell(Text(dept['code'])),
                      DataCell(Text(dept['type'])),
                      DataCell(Switch(
                        value: dept['active'],
                        onChanged: (v) {
                          setState(() => dept['active'] = v);
                          if (dept['id'] != null) {
                            WebApiService.setDepartmentActive(dept['id'] as int, v);
                          }
                        },
                        activeColor: const Color(0xFF1A56DB),
                      )),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () {},
                            tooltip: 'edit'.tr(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                departments.remove(dept);
                              });
                              if (dept['id'] != null) {
                                WebApiService.deleteDepartment(dept['id'] as int);
                              }
                            },
                            tooltip: 'delete_button'.tr(),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            
            // Queue Settings
            _buildSettingsCard('web_queue_settings_title'.tr(), [
              _buildSliderTile('web_max_queue_per_counter'.tr(), maxQueuePerCounter, 5, 50, (v) => setState(() => maxQueuePerCounter = v)),
              _buildSliderTile('web_default_wait_time'.tr(), defaultWaitTime, 5, 60, (v) => setState(() => defaultWaitTime = v)),
              _buildSwitchTile('web_enable_emergency_queue'.tr(), 'web_enable_emergency_queue_sub'.tr(), enableEmergencyQueue, (v) => setState(() => enableEmergencyQueue = v)),
              _buildSwitchTile('web_enable_priority_queue'.tr(), 'web_enable_priority_queue_sub'.tr(), enablePriorityQueue, (v) => setState(() => enablePriorityQueue = v)),
              _buildSliderTile('web_priority_queue_limit'.tr(), priorityQueueLimit, 1, 10, (v) => setState(() => priorityQueueLimit = v)),
            ]),
            const SizedBox(height: 20),

            // Office Hours
            _buildSettingsCard('web_office_hours_title'.tr(), [
              _buildTimePickerTile('web_office_open_time'.tr(), officeOpenTime, (v) => setState(() => officeOpenTime = v)),
              _buildTimePickerTile('web_office_close_time'.tr(), officeCloseTime, (v) => setState(() => officeCloseTime = v)),
              _buildSwitchTile('web_saturday_open'.tr(), 'web_saturday_open_sub'.tr(), saturdayOpen, (v) => setState(() => saturdayOpen = v)),
              _buildSwitchTile('web_sunday_open'.tr(), 'web_sunday_open_sub'.tr(), sundayOpen, (v) => setState(() => sundayOpen = v)),
            ]),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveAllSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('web_save_all_settings'.tr(), style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ...children.map((child) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          )),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1A56DB),
    );
  }

  Widget _buildDropdownTile(String title, String value, List<String> items, Function(String) onChanged) {
    return ListTile(
      title: Text(title),
      subtitle: Text('web_current_value_label'.tr(args: [value]), style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: DropdownButton<String>(
        value: value,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  Widget _buildSliderTile(String title, int value, int min, int max, Function(int) onChanged) {
    return ListTile(
      title: Text(title),
      subtitle: Text('web_current_value_label'.tr(args: ['$value']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: SizedBox(
        width: 200,
        child: Row(
          children: [
            Text('$min'),
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: (max - min),
                onChanged: (v) => onChanged(v.toInt()),
                activeColor: const Color(0xFF1A56DB),
              ),
            ),
            Text('$max'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerTile(String title, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return ListTile(
      title: Text(title),
      subtitle: Text('web_current_value_label'.tr(args: [time.format(context)]), style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: OutlinedButton(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (picked != null) onChanged(picked);
        },
        child: Text(time.format(context)),
      ),
    );
  }
}