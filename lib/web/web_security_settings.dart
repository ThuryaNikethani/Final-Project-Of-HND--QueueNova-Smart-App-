import 'package:flutter/material.dart';

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
  List<String> whitelistedIPs = ['192.168.1.100', '192.168.1.101'];

  // Audit Log
  bool logAllActions = true;
  bool logFailedLogins = true;
  int retentionDays = 90;

  final List<Map<String, String>> auditLogs = [
    {'time': '2026-05-21 09:15:23', 'user': 'admin@queuenova.gov.lk', 'action': 'Logged in', 'ip': '192.168.1.100', 'status': 'Success'},
    {'time': '2026-05-21 08:45:12', 'user': 'queue@queuenova.gov.lk', 'action': 'Called token A-025', 'ip': '192.168.1.101', 'status': 'Success'},
    {'time': '2026-05-20 17:30:45', 'user': 'service@queuenova.gov.lk', 'action': 'Approved application', 'ip': '192.168.1.102', 'status': 'Success'},
    {'time': '2026-05-20 14:20:33', 'user': 'unknown', 'action': 'Failed login attempt', 'ip': '203.0.113.45', 'status': 'Failed'},
    {'time': '2026-05-20 10:05:22', 'user': 'reception@queuenova.gov.lk', 'action': 'Checked in citizen', 'ip': '192.168.1.103', 'status': 'Success'},
  ];

  void _showAddIPDialog() {
    final ipController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add IP to Whitelist'),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(
            labelText: 'IP Address',
            hintText: 'e.g., 192.168.1.100',
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
                whitelistedIPs.add(ipController.text);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('IP added to whitelist'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Password Policy
            _buildSecurityCard('Password Policy', [
              _buildSwitchTile('Require Uppercase Letters', 'Password must contain A-Z', requireUppercase, (v) => setState(() => requireUppercase = v)),
              _buildSwitchTile('Require Lowercase Letters', 'Password must contain a-z', requireLowercase, (v) => setState(() => requireLowercase = v)),
              _buildSwitchTile('Require Numbers', 'Password must contain 0-9', requireNumbers, (v) => setState(() => requireNumbers = v)),
              _buildSwitchTile('Require Special Characters', 'Password must contain !@#\$%', requireSpecialChars, (v) => setState(() => requireSpecialChars = v)),
              _buildSliderTile('Minimum Password Length', minPasswordLength, 6, 20, (v) => setState(() => minPasswordLength = v)),
              _buildSliderTile('Password Expiry (days)', passwordExpiryDays, 30, 365, (v) => setState(() => passwordExpiryDays = v)),
            ]),
            const SizedBox(height: 20),
            
            // Session Security
            _buildSecurityCard('Session Security', [
              _buildSwitchTile('Enable Session Timeout', 'Auto-logout inactive users', enableSessionTimeout, (v) => setState(() => enableSessionTimeout = v)),
              _buildSliderTile('Session Timeout (minutes)', sessionTimeoutMinutes, 5, 120, (v) => setState(() => sessionTimeoutMinutes = v)),
              _buildSwitchTile('Limit Concurrent Sessions', 'Restrict multiple logins', limitConcurrentSessions, (v) => setState(() => limitConcurrentSessions = v)),
              _buildSliderTile('Max Concurrent Sessions', maxConcurrentSessions, 1, 10, (v) => setState(() => maxConcurrentSessions = v)),
            ]),
            const SizedBox(height: 20),
            
            // Login Security
            _buildSecurityCard('Login Security', [
              _buildSwitchTile('Enable CAPTCHA', 'Show CAPTCHA on login', enableCaptcha, (v) => setState(() => enableCaptcha = v)),
              _buildSliderTile('Max Login Attempts', maxLoginAttempts, 3, 10, (v) => setState(() => maxLoginAttempts = v)),
              _buildSwitchTile('Notify on New Device', 'Email when new device logs in', notifyOnNewDevice, (v) => setState(() => notifyOnNewDevice = v)),
              _buildSwitchTile('Enable IP Whitelisting', 'Restrict access to trusted IPs', enableIpWhitelisting, (v) => setState(() => enableIpWhitelisting = v)),
              if (enableIpWhitelisting) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Whitelisted IPs', style: TextStyle(fontWeight: FontWeight.w500)),
                    TextButton.icon(
                      onPressed: _showAddIPDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add IP'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: whitelistedIPs.map((ip) => Chip(
                    label: Text(ip),
                    onDeleted: () => setState(() => whitelistedIPs.remove(ip)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                  )).toList(),
                ),
              ],
            ]),
            const SizedBox(height: 20),
            
            // Audit Log
            _buildSecurityCard('Audit Log', [
              _buildSwitchTile('Log All Actions', 'Record all user activities', logAllActions, (v) => setState(() => logAllActions = v)),
              _buildSwitchTile('Log Failed Logins', 'Record failed login attempts', logFailedLogins, (v) => setState(() => logFailedLogins = v)),
              _buildSliderTile('Retention Period (days)', retentionDays, 30, 365, (v) => setState(() => retentionDays = v)),
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
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Recent Audit Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 30,
                      columns: const [
                        DataColumn(label: Text('Timestamp')),
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('Action')),
                        DataColumn(label: Text('IP Address')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: auditLogs.map((log) {
                        final isSuccess = log['status'] == 'Success';
                        return DataRow(cells: [
                          DataCell(Text(log['time']!)),
                          DataCell(Text(log['user']!)),
                          DataCell(Text(log['action']!)),
                          DataCell(Text(log['ip']!)),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              log['status']!,
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Security settings saved successfully'), backgroundColor: Colors.green),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Security Settings', style: TextStyle(fontSize: 16)),
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
}