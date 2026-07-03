import 'package:flutter/material.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'web_role_model.dart';

class WebSettings extends StatefulWidget {
  final UserRole userRole;
  final String userName;
  final String userEmail;

  const WebSettings({
    super.key,
    required this.userRole,
    required this.userName,
    required this.userEmail,
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // Load saved settings from SharedPreferences would go here
    // For now using default values
  }

  void _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    // Save settings to SharedPreferences would go here
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      _saveSuccess = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: Colors.green,
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
        title: const Text('Reset Settings'),
        content: const Text(
            'Are you sure you want to reset all settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to default!')),
              );
            },
            child: const Text('Reset'),
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
        title: const Text('Settings'),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text('Saved',
                      style: TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: _resetToDefault,
            tooltip: 'Reset to Default',
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

                  // Role-Specific Dashboard Settings
                  _buildRoleSpecificSettings(),

                  const SizedBox(height: 16),

                  // Common Settings
                  _buildCommonSettings(),

                  const SizedBox(height: 24),

                  // Save Button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetToDefault,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset to Default'),
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
                          label: const Text('Save All Settings'),
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
          title: 'Queue Officer Dashboard',
          icon: Icons.queue_play_next,
          color: const Color(0xFF10B981),
          children: [
            _buildSwitchTile(
              title: 'Show Real-Time Queue Status',
              subtitle: 'Display live queue updates on your dashboard',
              value: _showRealTimeQueue,
              onChanged: (value) => setState(() => _showRealTimeQueue = value),
              icon: Icons.timeline,
            ),
            _buildSwitchTile(
              title: 'Auto-Assign Tokens',
              subtitle: 'Automatically assign queue tokens to customers',
              value: _autoAssignTokens,
              onChanged: (value) => setState(() => _autoAssignTokens = value),
              icon: Icons.qr_code_scanner,
            ),
            _buildSwitchTile(
              title: 'Send SMS Alerts',
              subtitle: 'Send SMS notifications to customers',
              value: _sendSMSAlerts,
              onChanged: (value) => setState(() => _sendSMSAlerts = value),
              icon: Icons.sms,
            ),
            _buildSliderTile(
              title: 'Maximum Queue Size',
              value: _maxQueueSize.toDouble(),
              min: 10,
              max: 200,
              onChanged: (value) =>
                  setState(() => _maxQueueSize = value.round()),
              suffix: 'tokens',
              icon: Icons.people,
            ),
            _buildSliderTile(
              title: 'Dashboard Refresh Interval',
              value: _refreshInterval.toDouble(),
              min: 15,
              max: 120,
              onChanged: (value) =>
                  setState(() => _refreshInterval = value.round()),
              suffix: 'seconds',
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
          title: 'Service Officer Dashboard',
          icon: Icons.assignment_turned_in,
          color: const Color(0xFF8B5CF6),
          children: [
            _buildSwitchTile(
              title: 'Show Service Metrics',
              subtitle: 'Display service completion statistics',
              value: _showServiceMetrics,
              onChanged: (value) => setState(() => _showServiceMetrics = value),
              icon: Icons.bar_chart,
            ),
            _buildSwitchTile(
              title: 'Auto-Refresh Services List',
              subtitle: 'Automatically refresh the services list',
              value: _autoRefreshServices,
              onChanged: (value) =>
                  setState(() => _autoRefreshServices = value),
              icon: Icons.autorenew,
            ),
            _buildSwitchTile(
              title: 'Show Customer History',
              subtitle: 'Display customer service history',
              value: _showCustomerHistory,
              onChanged: (value) =>
                  setState(() => _showCustomerHistory = value),
              icon: Icons.history,
            ),
            _buildSliderTile(
              title: 'Service Time Limit',
              value: _serviceTimeLimit.toDouble(),
              min: 5,
              max: 60,
              onChanged: (value) =>
                  setState(() => _serviceTimeLimit = value.round()),
              suffix: 'minutes',
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
          title: 'Reception Officer Dashboard',
          icon: Icons.receipt_long,
          color: const Color(0xFFF59E0B),
          children: [
            _buildSwitchTile(
              title: 'Show Walk-in Customers',
              subtitle: 'Display walk-in customer list',
              value: _showWalkInCustomers,
              onChanged: (value) =>
                  setState(() => _showWalkInCustomers = value),
              icon: Icons.people,
            ),
            _buildSwitchTile(
              title: 'Show Document Checklist',
              subtitle: 'Display required documents checklist',
              value: _showDocumentChecklist,
              onChanged: (value) =>
                  setState(() => _showDocumentChecklist = value),
              icon: Icons.checklist,
            ),
            _buildSwitchTile(
              title: 'Auto-Print Tokens',
              subtitle: 'Automatically print queue tokens',
              value: _autoPrintTokens,
              onChanged: (value) => setState(() => _autoPrintTokens = value),
              icon: Icons.print,
            ),
            _buildDropdownTile(
              title: 'Token Prefix',
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
          title: 'Supervisor Dashboard',
          icon: Icons.analytics,
          color: const Color(0xFFEC4899),
          children: [
            _buildSwitchTile(
              title: 'Show Officer Performance',
              subtitle: 'Display officer performance metrics',
              value: _showOfficerPerformance,
              onChanged: (value) =>
                  setState(() => _showOfficerPerformance = value),
              icon: Icons.assessment,
            ),
            _buildSwitchTile(
              title: 'Show Service Analytics',
              subtitle: 'Display service analytics and trends',
              value: _showServiceAnalytics,
              onChanged: (value) =>
                  setState(() => _showServiceAnalytics = value),
              icon: Icons.show_chart,
            ),
            _buildSwitchTile(
              title: 'Show Queue Alerts',
              subtitle: 'Display queue threshold alerts',
              value: _showQueueAlerts,
              onChanged: (value) => setState(() => _showQueueAlerts = value),
              icon: Icons.notifications_active,
            ),
            _buildSliderTile(
              title: 'Alert Threshold',
              value: _alertThreshold.toDouble(),
              min: 5,
              max: 50,
              onChanged: (value) =>
                  setState(() => _alertThreshold = value.round()),
              suffix: 'customers in queue',
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
          title: 'Administrator Dashboard',
          icon: Icons.admin_panel_settings,
          color: const Color(0xFFEF4444),
          children: [
            _buildSwitchTile(
              title: 'Show System Health',
              subtitle: 'Display system health metrics',
              value: _showSystemHealth,
              onChanged: (value) => setState(() => _showSystemHealth = value),
              icon: Icons.health_and_safety,
            ),
            _buildSwitchTile(
              title: 'Show User Activity',
              subtitle: 'Display user activity logs',
              value: _showUserActivity,
              onChanged: (value) => setState(() => _showUserActivity = value),
              icon: Icons.history,
            ),
            _buildSwitchTile(
              title: 'Auto-Backup System',
              subtitle: 'Automatically backup system data',
              value: _autoBackup,
              onChanged: (value) => setState(() => _autoBackup = value),
              icon: Icons.backup,
            ),
            _buildDropdownTile(
              title: 'Backup Schedule',
              value: _backupSchedule,
              items: const ['Daily', 'Weekly', 'Monthly'],
              onChanged: (value) => setState(() => _backupSchedule = value),
              icon: Icons.schedule,
            ),
            _buildDropdownTile(
              title: 'Log Retention Period',
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
      title: 'General Settings',
      icon: Icons.settings,
      color: const Color(0xFF1A56DB),
      children: [
        _buildDropdownTile(
          title: 'Language',
          value: _selectedLanguage,
          items: const ['English', 'Sinhala', 'Tamil'],
          onChanged: (value) => setState(() => _selectedLanguage = value),
          icon: Icons.language,
        ),
        _buildDropdownTile(
          title: 'Theme',
          value: _selectedTheme,
          items: const ['Light', 'Dark', 'System Default'],
          onChanged: (value) => setState(() => _selectedTheme = value),
          icon: Icons.palette,
        ),
        _buildDropdownTile(
          title: 'Font Size',
          value: _selectedFontSize,
          items: const ['Small', 'Medium', 'Large'],
          onChanged: (value) => setState(() => _selectedFontSize = value),
          icon: Icons.text_fields,
        ),
        const Divider(),
        _buildSwitchTile(
          title: 'Email Notifications',
          subtitle: 'Receive email notifications',
          value: _emailNotifications,
          onChanged: (value) => setState(() => _emailNotifications = value),
          icon: Icons.email,
        ),
        _buildSwitchTile(
          title: 'Push Notifications',
          subtitle: 'Receive browser push notifications',
          value: _pushNotifications,
          onChanged: (value) => setState(() => _pushNotifications = value),
          icon: Icons.notifications,
        ),
        _buildSwitchTile(
          title: 'Sound Alerts',
          subtitle: 'Play sound for notifications',
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
