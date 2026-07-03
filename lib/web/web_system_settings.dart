import 'package:flutter/material.dart';

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

  void _showAddDepartmentDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    String selectedType = 'Divisional Secretariat';
    final List<String> types = ['Divisional Secretariat', 'RMV', 'Passport Office', 'Registration', 'NIC Center', 'Other'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Department'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Department Name',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Department Code',
                  prefixIcon: Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Department Type',
                  prefixIcon: Icon(Icons.category),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                departments.add({
                  'name': nameController.text,
                  'code': codeController.text,
                  'active': true,
                  'type': selectedType,
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Department added successfully'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: const Text('Add Department'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // General Settings
            _buildSettingsCard('General Settings', [
              _buildSwitchTile('Email Notifications', 'Receive email alerts for system events', emailNotifications, (v) => setState(() => emailNotifications = v)),
              _buildSwitchTile('SMS Notifications', 'Send SMS alerts to citizens', smsNotifications, (v) => setState(() => smsNotifications = v)),
              _buildSwitchTile('Push Notifications', 'Real-time push notifications', pushNotifications, (v) => setState(() => pushNotifications = v)),
              _buildDropdownTile('Default Language', defaultLanguage, ['English', 'Sinhala', 'Tamil'], (v) => setState(() => defaultLanguage = v)),
              _buildDropdownTile('Date Format', dateFormat, ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'], (v) => setState(() => dateFormat = v)),
              _buildDropdownTile('Time Zone', timeZone, ['Asia/Colombo', 'Asia/Kolkata', 'UTC'], (v) => setState(() => timeZone = v)),
            ]),
            const SizedBox(height: 20),
            
            // Department Management
            _buildSettingsCard('Department Management', [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showAddDepartmentDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Department'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Department Name')),
                    DataColumn(label: Text('Code')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: departments.map((dept) {
                    return DataRow(cells: [
                      DataCell(Text(dept['name'])),
                      DataCell(Text(dept['code'])),
                      DataCell(Text(dept['type'])),
                      DataCell(Switch(
                        value: dept['active'],
                        onChanged: (v) => setState(() => dept['active'] = v),
                        activeColor: const Color(0xFF1A56DB),
                      )),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () {},
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                departments.remove(dept);
                              });
                            },
                            tooltip: 'Delete',
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
            _buildSettingsCard('Queue Settings', [
              _buildSliderTile('Max Queue per Counter', maxQueuePerCounter, 5, 50, (v) => setState(() => maxQueuePerCounter = v)),
              _buildSliderTile('Default Wait Time (minutes)', defaultWaitTime, 5, 60, (v) => setState(() => defaultWaitTime = v)),
              _buildSwitchTile('Enable Emergency Queue', 'Allow emergency priority handling', enableEmergencyQueue, (v) => setState(() => enableEmergencyQueue = v)),
              _buildSwitchTile('Enable Priority Queue', 'Priority for seniors/disabled/pregnant', enablePriorityQueue, (v) => setState(() => enablePriorityQueue = v)),
              _buildSliderTile('Priority Queue Limit', priorityQueueLimit, 1, 10, (v) => setState(() => priorityQueueLimit = v)),
            ]),
            const SizedBox(height: 20),
            
            // Office Hours
            _buildSettingsCard('Office Hours', [
              _buildTimePickerTile('Office Open Time', officeOpenTime, (v) => setState(() => officeOpenTime = v)),
              _buildTimePickerTile('Office Close Time', officeCloseTime, (v) => setState(() => officeCloseTime = v)),
              _buildSwitchTile('Saturday Open', 'Office open on Saturdays', saturdayOpen, (v) => setState(() => saturdayOpen = v)),
              _buildSwitchTile('Sunday Open', 'Office open on Sundays', sundayOpen, (v) => setState(() => sundayOpen = v)),
            ]),
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All settings saved successfully'), backgroundColor: Colors.green),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save All Settings', style: TextStyle(fontSize: 16)),
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
      subtitle: Text('Current: $value', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
      subtitle: Text('Current: $value', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
      subtitle: Text('Current: ${time.format(context)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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