import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebSecuritySettings extends StatefulWidget {
  const WebSecuritySettings({super.key});

  @override
  State<WebSecuritySettings> createState() => _WebSecuritySettingsState();
}

class _WebSecuritySettingsState extends State<WebSecuritySettings> {
  // Password Policy
  bool requireUppercase = true;
  bool requireLowercase = true;
  bool requireNumbers = true;
  bool requireSpecialChars = true;
  int minPasswordLength = 8;
  int passwordExpiryDays = 90;

  // Session Security
  bool enableSessionTimeout = true;
  int sessionTimeoutMinutes = 30;
  bool limitConcurrentSessions = true;
  int maxConcurrentSessions = 3;

  // Login Security
  bool enableCaptcha = true;
  int maxLoginAttempts = 5;
  bool notifyOnNewDevice = true;
  bool enableIpWhitelisting = false;
  List<String> whitelistedIPs = [];

  // Audit Log
  bool logAllActions = true;
  bool logFailedLogins = true;
  int retentionDays = 90;

  bool _saving = false;
  bool _loadingLogs = true;
  List<Map<String, dynamic>> auditLogs = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAuditLogs();
  }

  Future<void> _loadSettings() async {
    final res = await WebApiService.getSecuritySettings();
    final settings = res?['settings'] as Map<String, dynamic>?;
    if (!mounted || settings == null || settings.isEmpty) return;
    setState(() {
      requireUppercase = settings['requireUppercase'] as bool? ?? requireUppercase;
      requireLowercase = settings['requireLowercase'] as bool? ?? requireLowercase;
      requireNumbers = settings['requireNumbers'] as bool? ?? requireNumbers;
      requireSpecialChars = settings['requireSpecialChars'] as bool? ?? requireSpecialChars;
      minPasswordLength = settings['minPasswordLength'] as int? ?? minPasswordLength;
      passwordExpiryDays = settings['passwordExpiryDays'] as int? ?? passwordExpiryDays;
      enableSessionTimeout = settings['enableSessionTimeout'] as bool? ?? enableSessionTimeout;
      sessionTimeoutMinutes = settings['sessionTimeoutMinutes'] as int? ?? sessionTimeoutMinutes;
      limitConcurrentSessions = settings['limitConcurrentSessions'] as bool? ?? limitConcurrentSessions;
      maxConcurrentSessions = settings['maxConcurrentSessions'] as int? ?? maxConcurrentSessions;
      enableCaptcha = settings['enableCaptcha'] as bool? ?? enableCaptcha;
      maxLoginAttempts = settings['maxLoginAttempts'] as int? ?? maxLoginAttempts;
      notifyOnNewDevice = settings['notifyOnNewDevice'] as bool? ?? notifyOnNewDevice;
      enableIpWhitelisting = settings['enableIpWhitelisting'] as bool? ?? enableIpWhitelisting;
      whitelistedIPs = (settings['whitelistedIPs'] as List?)?.cast<String>() ?? whitelistedIPs;
      logAllActions = settings['logAllActions'] as bool? ?? logAllActions;
      logFailedLogins = settings['logFailedLogins'] as bool? ?? logFailedLogins;
      retentionDays = settings['retentionDays'] as int? ?? retentionDays;
    });
  }

  Future<void> _loadAuditLogs() async {
    final logs = await WebApiService.getAuditLogs(limit: 50);
    if (!mounted) return;
    setState(() {
      auditLogs = logs;
      _loadingLogs = false;
    });
  }

  Map<String, dynamic> _currentSettingsMap() => {
        'requireUppercase': requireUppercase,
        'requireLowercase': requireLowercase,
        'requireNumbers': requireNumbers,
        'requireSpecialChars': requireSpecialChars,
        'minPasswordLength': minPasswordLength,
        'passwordExpiryDays': passwordExpiryDays,
        'enableSessionTimeout': enableSessionTimeout,
        'sessionTimeoutMinutes': sessionTimeoutMinutes,
        'limitConcurrentSessions': limitConcurrentSessions,
        'maxConcurrentSessions': maxConcurrentSessions,
        'enableCaptcha': enableCaptcha,
        'maxLoginAttempts': maxLoginAttempts,
        'notifyOnNewDevice': notifyOnNewDevice,
        'enableIpWhitelisting': enableIpWhitelisting,
        'whitelistedIPs': whitelistedIPs,
        'logAllActions': logAllActions,
        'logFailedLogins': logFailedLogins,
        'retentionDays': retentionDays,
      };

  Future<void> _saveAllSettings() async {
    setState(() => _saving = true);
    final success = await WebApiService.saveSecuritySettings(_currentSettingsMap());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'web_security_settings_saved_success'.tr() : 'web_settings_save_failed'.tr()),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  /// Persists the IP whitelist immediately (same pattern as Department
  /// add/remove in System Settings), independent of the main Save button.
  Future<void> _persistIpWhitelist() async {
    await WebApiService.saveSecuritySettings(_currentSettingsMap());
  }

  String _formatLogTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    } catch (_) {
      return iso;
    }
  }

  bool _isFailureAction(String action) => action.contains('failed') || action.contains('blocked');

  void _showAddIPDialog() {
    final ipController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_add_ip_whitelist_title'.tr()),
        content: TextField(
          controller: ipController,
          decoration: InputDecoration(
            labelText: 'web_ip_address_label'.tr(),
            hintText: 'web_ip_address_hint'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                whitelistedIPs.add(ipController.text);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('web_ip_added_success'.tr()), backgroundColor: Colors.green),
              );
              _persistIpWhitelist();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: Text('web_add_button'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('web_security_settings_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Password Policy
            _buildSecurityCard('web_password_policy_title'.tr(), [
              _buildSwitchTile('web_require_uppercase'.tr(), 'web_require_uppercase_sub'.tr(), requireUppercase, (v) => setState(() => requireUppercase = v)),
              _buildSwitchTile('web_require_lowercase'.tr(), 'web_require_lowercase_sub'.tr(), requireLowercase, (v) => setState(() => requireLowercase = v)),
              _buildSwitchTile('web_require_numbers'.tr(), 'web_require_numbers_sub'.tr(), requireNumbers, (v) => setState(() => requireNumbers = v)),
              _buildSwitchTile('web_require_special_chars'.tr(), 'web_require_special_chars_sub'.tr(), requireSpecialChars, (v) => setState(() => requireSpecialChars = v)),
              _buildSliderTile('web_min_password_length'.tr(), minPasswordLength, 6, 20, (v) => setState(() => minPasswordLength = v)),
              _buildSliderTile('web_password_expiry_days'.tr(), passwordExpiryDays, 30, 365, (v) => setState(() => passwordExpiryDays = v)),
            ]),
            const SizedBox(height: 20),

            // Session Security
            _buildSecurityCard('web_session_security_title'.tr(), [
              _buildSwitchTile('web_enable_session_timeout'.tr(), 'web_enable_session_timeout_sub'.tr(), enableSessionTimeout, (v) => setState(() => enableSessionTimeout = v)),
              _buildSliderTile('web_session_timeout_minutes'.tr(), sessionTimeoutMinutes, 5, 120, (v) => setState(() => sessionTimeoutMinutes = v)),
              _buildSwitchTile('web_limit_concurrent_sessions'.tr(), 'web_limit_concurrent_sessions_sub'.tr(), limitConcurrentSessions, (v) => setState(() => limitConcurrentSessions = v)),
              _buildSliderTile('web_max_concurrent_sessions'.tr(), maxConcurrentSessions, 1, 10, (v) => setState(() => maxConcurrentSessions = v)),
            ]),
            const SizedBox(height: 20),

            // Login Security
            _buildSecurityCard('web_login_security_title'.tr(), [
              _buildSwitchTile('web_enable_captcha'.tr(), 'web_enable_captcha_sub'.tr(), enableCaptcha, (v) => setState(() => enableCaptcha = v)),
              _buildSliderTile('web_max_login_attempts'.tr(), maxLoginAttempts, 3, 10, (v) => setState(() => maxLoginAttempts = v)),
              _buildSwitchTile('web_notify_new_device'.tr(), 'web_notify_new_device_sub'.tr(), notifyOnNewDevice, (v) => setState(() => notifyOnNewDevice = v)),
              _buildSwitchTile('web_enable_ip_whitelisting'.tr(), 'web_enable_ip_whitelisting_sub'.tr(), enableIpWhitelisting, (v) => setState(() => enableIpWhitelisting = v)),
              if (enableIpWhitelisting) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('web_whitelisted_ips'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                    TextButton.icon(
                      onPressed: _showAddIPDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('web_add_ip_button'.tr()),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: whitelistedIPs.map((ip) => Chip(
                    label: Text(ip),
                    onDeleted: () {
                      setState(() => whitelistedIPs.remove(ip));
                      _persistIpWhitelist();
                    },
                    deleteIcon: const Icon(Icons.close, size: 14),
                  )).toList(),
                ),
              ],
            ]),
            const SizedBox(height: 20),
            
            // Audit Log
            _buildSecurityCard('web_audit_log_title'.tr(), [
              _buildSwitchTile('web_log_all_actions'.tr(), 'web_log_all_actions_sub'.tr(), logAllActions, (v) => setState(() => logAllActions = v)),
              _buildSwitchTile('web_log_failed_logins'.tr(), 'web_log_failed_logins_sub'.tr(), logFailedLogins, (v) => setState(() => logFailedLogins = v)),
              _buildSliderTile('web_retention_period_days'.tr(), retentionDays, 30, 365, (v) => setState(() => retentionDays = v)),
            ]),
            const SizedBox(height: 20),

            // Recent Audit Logs
            Container(
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
                    child: Text('web_recent_audit_logs'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  _loadingLogs
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : auditLogs.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(child: Text('web_no_audit_logs'.tr())),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 30,
                                columns: [
                                  DataColumn(label: Text('web_col_timestamp'.tr())),
                                  DataColumn(label: Text('web_col_user'.tr())),
                                  DataColumn(label: Text('web_col_action'.tr())),
                                  DataColumn(label: Text('web_col_ip_address'.tr())),
                                  DataColumn(label: Text('web_col_status'.tr())),
                                ],
                                rows: auditLogs.map((log) {
                                  final action = log['action']?.toString() ?? '';
                                  final isSuccess = !_isFailureAction(action);
                                  return DataRow(cells: [
                                    DataCell(Text(_formatLogTime(log['created_at']?.toString()))),
                                    DataCell(Text(log['user_name']?.toString() ?? '—')),
                                    DataCell(Text(log['details']?.toString().isNotEmpty == true ? log['details'].toString() : action)),
                                    DataCell(Text(log['ip_address']?.toString() ?? '—')),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isSuccess ? 'web_status_success'.tr() : 'web_status_failed'.tr(),
                                        style: TextStyle(color: isSuccess ? Colors.green : Colors.red),
                                      ),
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
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
                    : Text('web_save_security_settings'.tr(), style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard(String title, List<Widget> children) {
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
}