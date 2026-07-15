import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebAuditLogs extends StatefulWidget {
  const WebAuditLogs({super.key});

  @override
  State<WebAuditLogs> createState() => _WebAuditLogsState();
}

class _WebAuditLogsState extends State<WebAuditLogs> {
  String searchQuery = '';
  String selectedUser = 'All Users';
  String selectedAction = 'All Actions';

  bool _loading = true;
  List<Map<String, dynamic>> auditLogs = [];

  // Populated from the real data actually loaded, so these always match
  // what's genuinely in the audit trail instead of a fixed guessed list.
  List<String> get users => ['All Users', ...{for (final l in auditLogs) l['userRole'] as String}.toList()..sort()];
  List<String> get actions => ['All Actions', ...{for (final l in auditLogs) l['action'] as String}.toList()..sort()];

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    final logs = await WebApiService.getAuditLogs(limit: 500);
    if (!mounted) return;
    setState(() {
      auditLogs = logs.map((r) {
        final action = r['action']?.toString() ?? '';
        return {
          'time': _formatTime(r['created_at']?.toString()),
          'user': r['user_name']?.toString() ?? 'System',
          'userRole': r['user_role']?.toString() ?? 'Unknown',
          'action': action,
          'ip': r['ip_address']?.toString() ?? '—',
          'status': _isFailureAction(action) ? 'Failed' : 'Success',
          'details': r['details']?.toString().isNotEmpty == true ? r['details'].toString() : action,
        };
      }).toList();
      _loading = false;
    });
  }

  String _formatTime(String? iso) {
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

  List<Map<String, dynamic>> get filteredLogs {
    return auditLogs.where((log) {
      final matchesSearch = searchQuery.isEmpty ||
          log['user'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          log['action'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          log['details'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      final matchesUser = selectedUser == 'All Users' || log['userRole'] == selectedUser;
      final matchesAction = selectedAction == 'All Actions' || log['action'] == selectedAction;
      return matchesSearch && matchesUser && matchesAction;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      selectedUser = 'All Users';
      selectedAction = 'All Actions';
    });
  }

  void _exportLogs() {
    final rows = filteredLogs;
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,User,Role,Action,IP Address,Status,Details');
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    for (final log in rows) {
      buffer.writeln([
        esc(log['time'] as String),
        esc(log['user'] as String),
        esc(_userRoleLabel(log['userRole'] as String)),
        esc(_actionLabel(log['action'] as String)),
        esc(log['ip'] as String),
        esc(log['status'] as String),
        esc(log['details'] as String),
      ].join(','));
    }

    final blob = html.Blob([buffer.toString()], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'audit_logs_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('web_exporting_logs'.tr()), backgroundColor: Colors.blue),
    );
  }

  String _prettify(String raw) => raw
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _userRoleLabel(String role) {
    switch (role) {
      case 'All Users': return 'web_all_users'.tr();
      case 'Administrator': return 'web_admin_label'.tr();
      case 'Queue Manager': return 'web_queue_officer_label'.tr();
      case 'Service Officer': return 'web_role_short_service_officer'.tr();
      case 'Reception': return 'web_role_short_reception'.tr();
      case 'Department Manager': return 'web_manager_label'.tr();
      case 'Unknown': return 'web_unknown'.tr();
      default: return role;
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'All Actions': return 'web_all_actions'.tr();
      case 'login': return 'web_action_login'.tr();
      case 'failed_login': return 'web_action_login'.tr();
      case 'logout': return 'web_action_logout'.tr();
      case 'create_user': return 'web_action_create'.tr();
      case 'update_user': return 'web_action_update'.tr();
      case 'delete_user': return 'delete_button'.tr();
      case 'approve_document': return 'web_approve_button'.tr();
      case 'reject_document': return 'web_reject_button'.tr();
      case 'call_next': return 'web_action_call_token'.tr();
      case 'generate_report': return 'web_action_export'.tr();
      default: return _prettify(action);
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('failed') || action.contains('blocked') || action.contains('delete') || action.contains('reject')) return Colors.red;
    switch (action) {
      case 'login': return Colors.blue;
      case 'logout': return Colors.grey;
      case 'create_user': case 'add_department': case 'add_queue': case 'approve_document': return Colors.green;
      case 'update_user': case 'update_system_settings': case 'update_security_settings': return Colors.purple;
      case 'call_next': return const Color(0xFF1A56DB);
      default: return const Color(0xFF1A56DB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: Text('web_menu_audit_logs'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          onChanged: (v) => setState(() => searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'web_search_logs_hint'.tr(),
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedUser,
                          decoration: InputDecoration(
                            labelText: 'web_user_role_label'.tr(),
                            border: const OutlineInputBorder(),
                          ),
                          items: users.map((u) => DropdownMenuItem(value: u, child: Text(_userRoleLabel(u)))).toList(),
                          onChanged: (v) => setState(() => selectedUser = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedAction,
                          decoration: InputDecoration(
                            labelText: 'web_action_type_label'.tr(),
                            border: const OutlineInputBorder(),
                          ),
                          items: actions.map((a) => DropdownMenuItem(value: a, child: Text(_actionLabel(a)))).toList(),
                          onChanged: (v) => setState(() => selectedAction = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('web_total_logs_label'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${filtered.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56DB))),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear),
                        label: Text('web_clear_filters'.tr()),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _exportLogs,
                        icon: const Icon(Icons.download),
                        label: Text('web_export_logs'.tr()),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Audit Logs Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 30,
                    columns: [
                      DataColumn(label: Text('web_col_timestamp'.tr())),
                      DataColumn(label: Text('web_col_user'.tr())),
                      DataColumn(label: Text('web_col_role'.tr())),
                      DataColumn(label: Text('web_col_action'.tr())),
                      DataColumn(label: Text('web_col_ip_address'.tr())),
                      DataColumn(label: Text('web_col_status'.tr())),
                      DataColumn(label: Text('web_col_details'.tr())),
                    ],
                    rows: filtered.map((log) {
                      final isSuccess = log['status'] == 'Success';
                      return DataRow(cells: [
                        DataCell(Text(log['time'])),
                        DataCell(Text(log['user'])),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_userRoleLabel(log['userRole'] as String), style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getActionColor(log['action']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_actionLabel(log['action'] as String), style: TextStyle(fontSize: 11, color: _getActionColor(log['action']))),
                        )),
                        DataCell(Text(log['ip'])),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(isSuccess ? 'web_status_success'.tr() : 'web_status_failed'.tr(), style: TextStyle(color: isSuccess ? Colors.green : Colors.red)),
                        )),
                        DataCell(Text(log['details'], style: const TextStyle(fontSize: 12))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}