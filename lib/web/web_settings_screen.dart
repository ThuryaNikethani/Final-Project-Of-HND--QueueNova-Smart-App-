import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'web_role_model.dart';
import 'web_api_service.dart';
import 'web_preferences_provider.dart';

class WebSettings extends StatefulWidget {
  final UserRole userRole;
  final String userName;
  final String userEmail;
  final String staffId;

  const WebSettings({
    super.key,
    required this.userRole,
    required this.userName,
    required this.userEmail,
    required this.staffId,
  });

  @override
  State<WebSettings> createState() => _WebSettingsState();
}

class _WebSettingsState extends State<WebSettings> {
  bool _isLoading = false;
  bool _saveSuccess = false;

  // Common Settings
  String _selectedLanguage = 'English';
  String _selectedTheme = 'Light';
  String _selectedFontSize = 'Medium';
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _soundEnabled = true;

  // Queue Officer Settings
  bool _showRealTimeQueue = true;
  bool _autoAssignTokens = true;
  bool _sendSMSAlerts = true;
  int _maxQueueSize = 50;
  int _refreshInterval = 30;

  // Service Officer Settings
  bool _showServiceMetrics = true;
  bool _autoRefreshServices = true;
  bool _showCustomerHistory = true;
  int _serviceTimeLimit = 15;

  // Reception Officer Settings
  bool _showWalkInCustomers = true;
  bool _showDocumentChecklist = true;
  bool _autoPrintTokens = true;
  int _tokenPrefix = 1;

  // Supervisor Settings
  bool _showOfficerPerformance = true;
  bool _showServiceAnalytics = true;
  bool _showQueueAlerts = true;
  int _alertThreshold = 10;

  // Administrator Settings
  bool _showSystemHealth = true;
  bool _showUserActivity = true;
  bool _autoBackup = true;
  String _backupSchedule = 'Daily';
  String _logRetention = '30 days';

  /// staff_users.id — null when logged in via the hardcoded-fallback demo
  /// login path (no real backend account to persist settings against).
  int? get _numericStaffId => int.tryParse(widget.staffId);

  Map<String, dynamic> _toJson() => {
        'selectedLanguage': _selectedLanguage,
        'selectedTheme': _selectedTheme,
        'selectedFontSize': _selectedFontSize,
        'emailNotifications': _emailNotifications,
        'pushNotifications': _pushNotifications,
        'soundEnabled': _soundEnabled,
        'showRealTimeQueue': _showRealTimeQueue,
        'autoAssignTokens': _autoAssignTokens,
        'sendSMSAlerts': _sendSMSAlerts,
        'maxQueueSize': _maxQueueSize,
        'refreshInterval': _refreshInterval,
        'showServiceMetrics': _showServiceMetrics,
        'autoRefreshServices': _autoRefreshServices,
        'showCustomerHistory': _showCustomerHistory,
        'serviceTimeLimit': _serviceTimeLimit,
        'showWalkInCustomers': _showWalkInCustomers,
        'showDocumentChecklist': _showDocumentChecklist,
        'autoPrintTokens': _autoPrintTokens,
        'tokenPrefix': _tokenPrefix,
        'showOfficerPerformance': _showOfficerPerformance,
        'showServiceAnalytics': _showServiceAnalytics,
        'showQueueAlerts': _showQueueAlerts,
        'alertThreshold': _alertThreshold,
        'showSystemHealth': _showSystemHealth,
        'showUserActivity': _showUserActivity,
        'autoBackup': _autoBackup,
        'backupSchedule': _backupSchedule,
        'logRetention': _logRetention,
      };

  void _applyJson(Map<String, dynamic> json) {
    _selectedLanguage = json['selectedLanguage'] as String? ?? _selectedLanguage;
    _selectedTheme = json['selectedTheme'] as String? ?? _selectedTheme;
    _selectedFontSize = json['selectedFontSize'] as String? ?? _selectedFontSize;
    _emailNotifications = json['emailNotifications'] as bool? ?? _emailNotifications;
    _pushNotifications = json['pushNotifications'] as bool? ?? _pushNotifications;
    _soundEnabled = json['soundEnabled'] as bool? ?? _soundEnabled;
    _showRealTimeQueue = json['showRealTimeQueue'] as bool? ?? _showRealTimeQueue;
    _autoAssignTokens = json['autoAssignTokens'] as bool? ?? _autoAssignTokens;
    _sendSMSAlerts = json['sendSMSAlerts'] as bool? ?? _sendSMSAlerts;
    _maxQueueSize = (json['maxQueueSize'] as num?)?.toInt() ?? _maxQueueSize;
    _refreshInterval = (json['refreshInterval'] as num?)?.toInt() ?? _refreshInterval;
    _showServiceMetrics = json['showServiceMetrics'] as bool? ?? _showServiceMetrics;
    _autoRefreshServices = json['autoRefreshServices'] as bool? ?? _autoRefreshServices;
    _showCustomerHistory = json['showCustomerHistory'] as bool? ?? _showCustomerHistory;
    _serviceTimeLimit = (json['serviceTimeLimit'] as num?)?.toInt() ?? _serviceTimeLimit;
    _showWalkInCustomers = json['showWalkInCustomers'] as bool? ?? _showWalkInCustomers;
    _showDocumentChecklist = json['showDocumentChecklist'] as bool? ?? _showDocumentChecklist;
    _autoPrintTokens = json['autoPrintTokens'] as bool? ?? _autoPrintTokens;
    _tokenPrefix = (json['tokenPrefix'] as num?)?.toInt() ?? _tokenPrefix;
    _showOfficerPerformance = json['showOfficerPerformance'] as bool? ?? _showOfficerPerformance;
    _showServiceAnalytics = json['showServiceAnalytics'] as bool? ?? _showServiceAnalytics;
    _showQueueAlerts = json['showQueueAlerts'] as bool? ?? _showQueueAlerts;
    _alertThreshold = (json['alertThreshold'] as num?)?.toInt() ?? _alertThreshold;
    _showSystemHealth = json['showSystemHealth'] as bool? ?? _showSystemHealth;
    _showUserActivity = json['showUserActivity'] as bool? ?? _showUserActivity;
    _autoBackup = json['autoBackup'] as bool? ?? _autoBackup;
    _backupSchedule = json['backupSchedule'] as String? ?? _backupSchedule;
    _logRetention = json['logRetention'] as String? ?? _logRetention;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final id = _numericStaffId;
    if (id == null) return;
    final prefs = await WebApiService.getUserPreferences(id);
    if (!mounted || prefs.isEmpty) return;
    setState(() => _applyJson(prefs));
    _applyLivePreferences();
  }

  /// Pushes the current Theme/Font Size/Language selections out to the
  /// rest of the app (WebPreferencesProvider + easy_localization) instead
  /// of only updating this screen's own local state.
  void _applyLivePreferences() {
    context.read<WebPreferencesProvider>().setThemeModeByName(_selectedTheme);
    context.read<WebPreferencesProvider>().setFontScaleByName(_selectedFontSize);
    final code = switch (_selectedLanguage) {
      'Sinhala' => 'si',
      'Tamil' => 'ta',
      _ => 'en',
    };
    if (context.locale.languageCode != code) {
      context.setLocale(Locale(code));
    }
  }

  void _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    final id = _numericStaffId;
    final success = id == null || await WebApiService.updateUserPreferences(id, _toJson());

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _saveSuccess = success;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'web_settings_saved_success'.tr() : 'web_settings_save_failed'.tr()),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _saveSuccess = false;
        });
      }
    });
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_reset_settings_title'.tr()),
        content: Text('web_reset_settings_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                // Reset common settings
                _selectedLanguage = 'English';
                _selectedTheme = 'Light';
                _selectedFontSize = 'Medium';
                _emailNotifications = true;
                _pushNotifications = true;
                _soundEnabled = true;

                // Reset role-specific settings
                _showRealTimeQueue = true;
                _autoAssignTokens = true;
                _sendSMSAlerts = true;
                _maxQueueSize = 50;
                _refreshInterval = 30;
                _showServiceMetrics = true;
                _autoRefreshServices = true;
                _showCustomerHistory = true;
                _serviceTimeLimit = 15;
                _showWalkInCustomers = true;
                _showDocumentChecklist = true;
                _autoPrintTokens = true;
                _tokenPrefix = 1;
                _showOfficerPerformance = true;
                _showServiceAnalytics = true;
                _showQueueAlerts = true;
                _alertThreshold = 10;
                _showSystemHealth = true;
                _showUserActivity = true;
                _autoBackup = true;
                _backupSchedule = 'Daily';
                _logRetention = '30 days';
              });
              _applyLivePreferences();
              final id = _numericStaffId;
              if (id != null) {
                WebApiService.updateUserPreferences(id, _toJson());
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('web_settings_reset_success'.tr())),
              );
            },
            child: Text('web_reset'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('web_settings'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_saveSuccess)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text('web_saved'.tr(),
                      style: const TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: _resetToDefault,
            tooltip: 'web_reset_to_default'.tr(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings,
                            size: 28,
                            color: Color(0xFF1A56DB),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                RolePermissions.getRoleName(widget.userRole),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.userEmail.split('@')[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Role-Specific Dashboard Settings (already includes the
                  // common "General Settings" section at its end for every
                  // role variant — do not add another _buildCommonSettings()
                  // call here, or it renders twice).
                  _buildRoleSpecificSettings(),

                  const SizedBox(height: 24),

                  // Save Button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetToDefault,
                          icon: const Icon(Icons.restart_alt),
                          label: Text('web_reset_to_default'.tr()),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save),
                          label: Text('web_save_all_settings'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56DB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildRoleSpecificSettings() {
    switch (widget.userRole) {
      case UserRole.queueManager:
        return _buildQueueOfficerSettings();
      case UserRole.serviceProcessor:
        return _buildServiceOfficerSettings();
      case UserRole.reception:
        return _buildReceptionOfficerSettings();
      case UserRole.departmentManager:
        return _buildSupervisorSettings();
      case UserRole.admin:
        return _buildAdministratorSettings();
    }
  }

  // ========== QUEUE OFFICER DASHBOARD SETTINGS ==========
  Widget _buildQueueOfficerSettings() {
    return Column(
      children: [
        _buildSettingsSection(
          title: 'web_settings_queue_officer_dashboard'.tr(),
          icon: Icons.queue_play_next,
          color: const Color(0xFF10B981),
          children: [
            _buildSwitchTile(
              title: 'web_settings_show_realtime_queue'.tr(),
              subtitle: 'web_settings_show_realtime_queue_sub'.tr(),
              value: _showRealTimeQueue,
              onChanged: (value) => setState(() => _showRealTimeQueue = value),
              icon: Icons.timeline,
            ),
            _buildSwitchTile(
              title: 'web_settings_auto_assign_tokens'.tr(),
              subtitle: 'web_settings_auto_assign_tokens_sub'.tr(),
              value: _autoAssignTokens,
              onChanged: (value) => setState(() => _autoAssignTokens = value),
              icon: Icons.qr_code_scanner,
            ),
            _buildSwitchTile(
              title: 'web_settings_send_sms_alerts'.tr(),
              subtitle: 'web_settings_send_sms_alerts_sub'.tr(),
              value: _sendSMSAlerts,
              onChanged: (value) => setState(() => _sendSMSAlerts = value),
              icon: Icons.sms,
            ),
            _buildSliderTile(
              title: 'web_settings_max_queue_size'.tr(),
              value: _maxQueueSize.toDouble(),
              min: 10,
              max: 200,
              onChanged: (value) =>
                  setState(() => _maxQueueSize = value.round()),
              suffix: 'web_settings_suffix_tokens'.tr(),
              icon: Icons.people,
            ),
            _buildSliderTile(
              title: 'web_settings_refresh_interval'.tr(),
              value: _refreshInterval.toDouble(),
              min: 15,
              max: 120,
              onChanged: (value) =>
                  setState(() => _refreshInterval = value.round()),
              suffix: 'web_settings_suffix_seconds'.tr(),
              icon: Icons.refresh,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCommonSettings(),
      ],
    );
  }

  // ========== SERVICE OFFICER DASHBOARD SETTINGS ==========
  Widget _buildServiceOfficerSettings() {
    return Column(
      children: [
        _buildSettingsSection(
          title: 'web_settings_service_officer_dashboard'.tr(),
          icon: Icons.assignment_turned_in,
          color: const Color(0xFF8B5CF6),
          children: [
            _buildSwitchTile(
              title: 'web_settings_show_service_metrics'.tr(),
              subtitle: 'web_settings_show_service_metrics_sub'.tr(),
              value: _showServiceMetrics,
              onChanged: (value) => setState(() => _showServiceMetrics = value),
              icon: Icons.bar_chart,
            ),
            _buildSwitchTile(
              title: 'web_settings_auto_refresh_services'.tr(),
              subtitle: 'web_settings_auto_refresh_services_sub'.tr(),
              value: _autoRefreshServices,
              onChanged: (value) =>
                  setState(() => _autoRefreshServices = value),
              icon: Icons.autorenew,
            ),
            _buildSwitchTile(
              title: 'web_settings_show_customer_history'.tr(),
              subtitle: 'web_settings_show_customer_history_sub'.tr(),
              value: _showCustomerHistory,
              onChanged: (value) =>
                  setState(() => _showCustomerHistory = value),
              icon: Icons.history,
            ),
            _buildSliderTile(
              title: 'web_settings_service_time_limit'.tr(),
              value: _serviceTimeLimit.toDouble(),
              min: 5,
              max: 60,
              onChanged: (value) =>
                  setState(() => _serviceTimeLimit = value.round()),
              suffix: 'web_settings_suffix_minutes'.tr(),
              icon: Icons.timer,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCommonSettings(),
      ],
    );
  }

  // ========== RECEPTION OFFICER DASHBOARD SETTINGS ==========
  Widget _buildReceptionOfficerSettings() {
    return Column(
      children: [
        _buildSettingsSection(
          title: 'web_settings_reception_officer_dashboard'.tr(),
          icon: Icons.receipt_long,
          color: const Color(0xFFF59E0B),
          children: [
            _buildSwitchTile(
              title: 'web_settings_show_walkin_customers'.tr(),
              subtitle: 'web_settings_show_walkin_customers_sub'.tr(),
              value: _showWalkInCustomers,
              onChanged: (value) =>
                  setState(() => _showWalkInCustomers = value),
              icon: Icons.people,
            ),
            _buildSwitchTile(
              title: 'web_settings_show_doc_checklist'.tr(),
              subtitle: 'web_settings_show_doc_checklist_sub'.tr(),
              value: _showDocumentChecklist,
              onChanged: (value) =>
                  setState(() => _showDocumentChecklist = value),
              icon: Icons.checklist,
            ),
            _buildSwitchTile(
              title: 'web_settings_auto_print_tokens'.tr(),
              subtitle: 'web_settings_auto_print_tokens_sub'.tr(),
              value: _autoPrintTokens,
              onChanged: (value) => setState(() => _autoPrintTokens = value),
              icon: Icons.print,
            ),
            _buildDropdownTile(
              title: 'web_settings_token_prefix'.tr(),
              value: _tokenPrefix.toString(),
              items: const ['1', '2', '3', '4', '5'],
              onChanged: (value) =>
                  setState(() => _tokenPrefix = int.parse(value)),
              icon: Icons.numbers,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCommonSettings(),
      ],
    );
  }

  // ========== SUPERVISOR DASHBOARD SETTINGS ==========
  Widget _buildSupervisorSettings() {
    return Column(
      children: [
        _buildSettingsSection(
          title: 'web_settings_supervisor_dashboard'.tr(),
          icon: Icons.analytics,
          color: const Color(0xFFEC4899),
          children: [
            _buildSwitchTile(
              title: 'web_settings_show_officer_performance'.tr(),
              subtitle: 'web_settings_show_officer_performance_sub'.tr(),
              value: _showOfficerPerformance,
              onChanged: (value) =>
                  setState(() => _showOfficerPerformance = value),
              icon: Icons.assessment,
            ),
            _buildSwitchTile(
              title: 'web_settings_show_service_analytics'.tr(),
              subtitle: 'web_settings_show_service_analytics_sub'.tr(),
              value: _showServiceAnalytics,
              onChanged: (value) =>
                  setState(() => _showServiceAnalytics = value),
              icon: Icons.show_chart,
            ),
            _buildSwitchTile(
              title: 'web_settings_show_queue_alerts'.tr(),
              subtitle: 'web_settings_show_queue_alerts_sub'.tr(),
              value: _showQueueAlerts,
              onChanged: (value) => setState(() => _showQueueAlerts = value),
              icon: Icons.notifications_active,
            ),
            _buildSliderTile(
              title: 'web_settings_alert_threshold'.tr(),
              value: _alertThreshold.toDouble(),
              min: 5,
              max: 50,
              onChanged: (value) =>
                  setState(() => _alertThreshold = value.round()),
              suffix: 'web_settings_suffix_customers_in_queue'.tr(),
              icon: Icons.warning,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCommonSettings(),
      ],
    );
  }

  // ========== ADMINISTRATOR DASHBOARD SETTINGS ==========
  Widget _buildAdministratorSettings() {
    return Column(
      children: [
        _buildSettingsSection(
          title: 'web_settings_administrator_dashboard'.tr(),
          icon: Icons.admin_panel_settings,
          color: const Color(0xFFEF4444),
          children: [
            _buildSwitchTile(
              title: 'web_settings_show_system_health'.tr(),
              subtitle: 'web_settings_show_system_health_sub'.tr(),
              value: _showSystemHealth,
              onChanged: (value) => setState(() => _showSystemHealth = value),
              icon: Icons.health_and_safety,
            ),
            _buildSwitchTile(
              title: 'web_settings_show_user_activity'.tr(),
              subtitle: 'web_settings_show_user_activity_sub'.tr(),
              value: _showUserActivity,
              onChanged: (value) => setState(() => _showUserActivity = value),
              icon: Icons.history,
            ),
            _buildSwitchTile(
              title: 'web_settings_auto_backup'.tr(),
              subtitle: 'web_settings_auto_backup_sub'.tr(),
              value: _autoBackup,
              onChanged: (value) => setState(() => _autoBackup = value),
              icon: Icons.backup,
            ),
            _buildDropdownTile(
              title: 'web_settings_backup_schedule'.tr(),
              value: _backupSchedule,
              items: const ['Daily', 'Weekly', 'Monthly'],
              onChanged: (value) => setState(() => _backupSchedule = value),
              icon: Icons.schedule,
            ),
            _buildDropdownTile(
              title: 'web_settings_log_retention'.tr(),
              value: _logRetention,
              items: const [
                '7 days',
                '15 days',
                '30 days',
                '60 days',
                '90 days'
              ],
              onChanged: (value) => setState(() => _logRetention = value),
              icon: Icons.storage,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCommonSettings(),
      ],
    );
  }

  // ========== COMMON SETTINGS FOR ALL USERS ==========
  Widget _buildCommonSettings() {
    return _buildSettingsSection(
      title: 'web_general_settings'.tr(),
      icon: Icons.settings,
      color: const Color(0xFF1A56DB),
      children: [
        _buildDropdownTile(
          title: 'web_settings_language'.tr(),
          value: _selectedLanguage,
          items: const ['English', 'Sinhala', 'Tamil'],
          onChanged: (value) {
            setState(() => _selectedLanguage = value);
            _applyLivePreferences();
          },
          icon: Icons.language,
        ),
        _buildDropdownTile(
          title: 'web_settings_theme'.tr(),
          value: _selectedTheme,
          items: const ['Light', 'Dark', 'System Default'],
          onChanged: (value) {
            setState(() => _selectedTheme = value);
            _applyLivePreferences();
          },
          icon: Icons.palette,
        ),
        _buildDropdownTile(
          title: 'web_settings_font_size'.tr(),
          value: _selectedFontSize,
          items: const ['Small', 'Medium', 'Large'],
          onChanged: (value) {
            setState(() => _selectedFontSize = value);
            _applyLivePreferences();
          },
          icon: Icons.text_fields,
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'web_settings_email_notifications'.tr(),
          subtitle: 'web_settings_email_notifications_sub'.tr(),
          value: _emailNotifications,
          onChanged: (value) => setState(() => _emailNotifications = value),
          icon: Icons.email,
        ),
        _buildSwitchTile(
          title: 'web_settings_push_notifications'.tr(),
          subtitle: 'web_settings_push_notifications_sub'.tr(),
          value: _pushNotifications,
          onChanged: (value) => setState(() => _pushNotifications = value),
          icon: Icons.notifications,
        ),
        _buildSwitchTile(
          title: 'web_settings_sound_alerts'.tr(),
          subtitle: 'web_settings_sound_alerts_sub'.tr(),
          value: _soundEnabled,
          onChanged: (value) => setState(() => _soundEnabled = value),
          icon: Icons.volume_up,
        ),
      ],
    );
  }

  // ========== UI COMPONENTS ==========
  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.grey.shade600),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1A56DB),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.grey.shade600),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: DropdownButton<String>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: (value) => onChanged(value!),
        style: const TextStyle(color: Color(0xFF1A56DB)),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
    required String suffix,
    required IconData icon,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.grey.shade600),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        children: [
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            label: '${value.round()} $suffix',
            onChanged: onChanged,
            activeColor: const Color(0xFF1A56DB),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A56DB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${value.round()} $suffix',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A56DB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
