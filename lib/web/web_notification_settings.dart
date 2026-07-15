import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebNotificationSettings extends StatefulWidget {
  final String staffId;

  const WebNotificationSettings({super.key, required this.staffId});

  @override
  State<WebNotificationSettings> createState() => _WebNotificationSettingsState();
}

class _WebNotificationSettingsState extends State<WebNotificationSettings> {
  bool emailNotifications = true;
  bool smsNotifications = true;
  bool pushNotifications = true;
  bool appointmentReminders = true;
  bool queueUpdates = true;
  bool _isLoading = false;

  /// Other keys already stored in this user's shared preferences blob
  /// (e.g. from WebSettings) — kept and re-sent on save so we don't
  /// clobber them, since the backend replaces the whole JSONB blob.
  Map<String, dynamic> _otherPrefs = {};

  int? get _numericStaffId => int.tryParse(widget.staffId);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final id = _numericStaffId;
    if (id == null) return;
    final prefs = await WebApiService.getUserPreferences(id);
    if (!mounted) return;
    setState(() {
      emailNotifications = prefs['notifEmailEnabled'] as bool? ?? emailNotifications;
      smsNotifications = prefs['notifSmsEnabled'] as bool? ?? smsNotifications;
      pushNotifications = prefs['notifPushEnabled'] as bool? ?? pushNotifications;
      appointmentReminders = prefs['notifAppointmentReminders'] as bool? ?? appointmentReminders;
      queueUpdates = prefs['notifQueueUpdates'] as bool? ?? queueUpdates;
      _otherPrefs = prefs;
    });
  }

  Future<void> _savePreferences() async {
    final id = _numericStaffId;
    if (id == null) return;
    setState(() => _isLoading = true);
    final success = await WebApiService.updateUserPreferences(id, {
      ..._otherPrefs,
      'notifEmailEnabled': emailNotifications,
      'notifSmsEnabled': smsNotifications,
      'notifPushEnabled': pushNotifications,
      'notifAppointmentReminders': appointmentReminders,
      'notifQueueUpdates': queueUpdates,
    });
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'web_settings_saved_generic'.tr() : 'web_settings_save_failed'.tr()),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('web_notification_settings'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePreferences,
            child: Text('save'.tr(), style: const TextStyle(color: Color(0xFF1A56DB))),
          ),
        ],
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('web_settings_email_notifications'.tr()),
            subtitle: Text('web_email_notif_sub'.tr()),
            value: emailNotifications,
            onChanged: (v) => setState(() => emailNotifications = v),
            activeColor: const Color(0xFF1A56DB),
          ),
          SwitchListTile(
            title: Text('web_sms_notifications'.tr()),
            subtitle: Text('web_sms_notif_sub'.tr()),
            value: smsNotifications,
            onChanged: (v) => setState(() => smsNotifications = v),
            activeColor: const Color(0xFF1A56DB),
          ),
          SwitchListTile(
            title: Text('web_settings_push_notifications'.tr()),
            subtitle: Text('web_push_notif_sub'.tr()),
            value: pushNotifications,
            onChanged: (v) => setState(() => pushNotifications = v),
            activeColor: const Color(0xFF1A56DB),
          ),
          const Divider(),
          SwitchListTile(
            title: Text('web_appointment_reminders'.tr()),
            subtitle: Text('web_appointment_reminders_sub'.tr()),
            value: appointmentReminders,
            onChanged: (v) => setState(() => appointmentReminders = v),
            activeColor: const Color(0xFF1A56DB),
          ),
          SwitchListTile(
            title: Text('web_queue_updates'.tr()),
            subtitle: Text('web_queue_updates_sub'.tr()),
            value: queueUpdates,
            onChanged: (v) => setState(() => queueUpdates = v),
            activeColor: const Color(0xFF1A56DB),
          ),
        ],
      ),
    );
  }
}