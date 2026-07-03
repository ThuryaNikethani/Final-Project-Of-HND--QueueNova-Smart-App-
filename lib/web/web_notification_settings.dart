import 'package:flutter/material.dart';

class WebNotificationSettings extends StatefulWidget {
  const WebNotificationSettings({super.key});

  @override
  State<WebNotificationSettings> createState() => _WebNotificationSettingsState();
}

class _WebNotificationSettingsState extends State<WebNotificationSettings> {
  bool emailNotifications = true;
  bool smsNotifications = true;
  bool pushNotifications = true;
  bool appointmentReminders = true;
  bool queueUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF1A56DB))),
          ),
        ],
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive notifications via email'),
            value: emailNotifications,
            onChanged: (v) => setState(() => emailNotifications = v),
            activeColor: const Color(0xFF1A56DB),
          ),
          SwitchListTile(
            title: const Text('SMS Notifications'),
            subtitle: const Text('Receive notifications via SMS'),
            value: smsNotifications,
            onChanged: (v) => setState(() => smsNotifications = v),
            activeColor: const Color(0xFF1A56DB),
          ),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive real-time push notifications'),
            value: pushNotifications,
            onChanged: (v) => setState(() => pushNotifications = v),
            activeColor: const Color(0xFF1A56DB),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Appointment Reminders'),
            subtitle: const Text('Get reminders about upcoming appointments'),
            value: appointmentReminders,
            onChanged: (v) => setState(() => appointmentReminders = v),
            activeColor: const Color(0xFF1A56DB),
          ),
          SwitchListTile(
            title: const Text('Queue Updates'),
            subtitle: const Text('Get notified when your token is called'),
            value: queueUpdates,
            onChanged: (v) => setState(() => queueUpdates = v),
            activeColor: const Color(0xFF1A56DB),
          ),
        ],
      ),
    );
  }
}