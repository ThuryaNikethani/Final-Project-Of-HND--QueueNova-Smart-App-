import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'web_api_service.dart';

class WebBackupRestore extends StatefulWidget {
  const WebBackupRestore({super.key});

  @override
  State<WebBackupRestore> createState() => _WebBackupRestoreState();
}

class _WebBackupRestoreState extends State<WebBackupRestore> {
  bool isBackingUp = false;
  bool isRestoring = false;
  bool _loading = true;
  String _selectedBackupFilter = 'All';

  List<Map<String, dynamic>> backups = [];

  String get lastBackupTime => backups.isNotEmpty ? backups.first['date'] as String : '—';
  String get lastBackupSize => backups.isNotEmpty ? backups.first['size'] as String : '—';
  int get backupCount => backups.length;
  String get backupStatus => backups.isNotEmpty ? backups.first['status'] as String : 'Success';

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  double _sizeMb(Map<String, dynamic> backup) =>
      double.tryParse((backup['size'] as String).replaceAll(' MB', '')) ?? 0;

  /// Postgres returns BIGINT columns as JSON strings (to avoid precision
  /// loss), not numbers, so this must handle both.
  num? _asNum(dynamic v) => v == null ? null : num.tryParse(v.toString());

  Future<void> _loadBackups() async {
    final rows = await WebApiService.getBackups();
    if (!mounted) return;
    setState(() {
      backups = rows.map((r) {
        final sizeBytes = _asNum(r['size_bytes'])?.toInt() ?? 0;
        return {
          'id': r['id'],
          'name': r['file_name']?.toString() ?? '',
          'date': _formatDate(r['created_at']?.toString()),
          'size': '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
          'type': r['backup_type']?.toString() ?? 'Full',
          'status': r['status']?.toString() ?? 'Success',
        };
      }).toList();
      _loading = false;
    });
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    } catch (_) {
      return iso;
    }
  }

  List<Map<String, dynamic>> get filteredBackups {
    if (_selectedBackupFilter == 'All') return backups;
    if (_selectedBackupFilter == 'Full') return backups.where((b) => b['type'] == 'Full').toList();
    if (_selectedBackupFilter == 'Incremental') return backups.where((b) => b['type'] == 'Incremental').toList();
    return backups;
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'Full': return 'web_type_full'.tr();
      case 'Incremental': return 'web_type_incremental'.tr();
      case 'All': return 'web_status_all'.tr();
      default: return type;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Success': return 'web_status_success'.tr();
      case 'In Progress': return 'web_backup_in_progress'.tr();
      default: return status;
    }
  }

  void _showBackupDetails(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.backup, color: Color(0xFF1A56DB)),
            const SizedBox(width: 10),
            Text('web_backup_details_title'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('web_backup_name_label'.tr(), backup['name']),
            const Divider(),
            _buildDetailRow('web_col_datetime'.tr(), backup['date']),
            const Divider(),
            _buildDetailRow('web_file_size_label'.tr(), backup['size']),
            const Divider(),
            _buildDetailRow('web_backup_type_label'.tr(), _typeLabel(backup['type'] as String)),
            const Divider(),
            _buildDetailRow('web_col_status'.tr(), _statusLabel(backup['status'] as String)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadBackup(backup);
            },
            icon: const Icon(Icons.download),
            label: Text('web_download'.tr()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showLastBackupDetails() {
    final lastBackup = backups.isNotEmpty ? backups.first : null;
    if (lastBackup != null) {
      _showBackupDetails(lastBackup);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('web_no_backup_found'.tr()), backgroundColor: Colors.red),
      );
    }
  }

  void _showTotalBackupSummary() {
    final fullBackups = backups.where((b) => b['type'] == 'Full').length;
    final incrementalBackups = backups.where((b) => b['type'] == 'Incremental').length;
    final totalSize = backups.fold<double>(0, (sum, b) {
      double size = double.tryParse(b['size'].replaceAll(' MB', '')) ?? 0;
      return sum + size;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.archive, color: Color(0xFF1A56DB)),
            const SizedBox(width: 10),
            Text('web_backup_summary_title'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('web_total_backups'.tr(), '$backupCount'),
            const Divider(),
            _buildSummaryRow('web_full_backups'.tr(), '$fullBackups'),
            const Divider(),
            _buildSummaryRow('web_incremental_backups'.tr(), '$incrementalBackups'),
            const Divider(),
            _buildSummaryRow('web_total_storage_used'.tr(), '${totalSize.toStringAsFixed(1)} MB'),
            const Divider(),
            _buildSummaryRow('web_oldest_backup'.tr(), backups.isEmpty ? '—' : backups.last['date']),
            const Divider(),
            _buildSummaryRow('web_latest_backup'.tr(), backups.isEmpty ? '—' : backups.first['date']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedBackupFilter = 'All';
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: Text('web_view_all_button'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showBackupStatusDetails() {
    final successfulBackups = backups.where((b) => b['status'] == 'Success').length;
    final failedBackups = backups.where((b) => b['status'] != 'Success').length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text('web_backup_status_title'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('web_current_status'.tr(), _statusLabel(backupStatus), backupStatus == 'Success' ? Colors.green : Colors.red),
            const Divider(),
            _buildStatusRow('web_successful_backups'.tr(), '$successfulBackups', Colors.green),
            const Divider(),
            _buildStatusRow('web_failed_backups'.tr(), '$failedBackups', failedBackups > 0 ? Colors.red : Colors.grey),
            const Divider(),
            _buildStatusRow('web_last_backup_time'.tr(), lastBackupTime, Colors.blue),
            const Divider(),
            _buildStatusRow('web_last_backup_size'.tr(), lastBackupSize, Colors.blue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showBackupSizeDetails() {
    final sizes = backups.map(_sizeMb).toList();
    final totalSize = sizes.fold<double>(0, (sum, s) => sum + s);
    final avgSize = sizes.isEmpty ? 0.0 : totalSize / sizes.length;
    final largest = sizes.isEmpty ? 0.0 : sizes.reduce((a, b) => a > b ? a : b);
    final smallest = sizes.isEmpty ? 0.0 : sizes.reduce((a, b) => a < b ? a : b);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.storage, color: Colors.green),
            const SizedBox(width: 10),
            Text('web_storage_details_title'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSizeRow('web_total_storage_used'.tr(), '${totalSize.toStringAsFixed(1)} MB', Colors.purple),
            const Divider(),
            _buildSizeRow('web_average_backup_size'.tr(), '${avgSize.toStringAsFixed(1)} MB', Colors.blue),
            const Divider(),
            _buildSizeRow('web_largest_backup'.tr(), '${largest.toStringAsFixed(1)} MB', Colors.orange),
            const Divider(),
            _buildSizeRow('web_smallest_backup'.tr(), '${smallest.toStringAsFixed(1)} MB', Colors.green),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _performBackup() async {
    setState(() => isBackingUp = true);

    final backup = await WebApiService.createBackup();

    if (!mounted) return;
    setState(() => isBackingUp = false);
    if (backup != null) {
      await _loadBackups();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('web_backup_completed_success'.tr()), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('web_backup_failed'.tr()), backgroundColor: Colors.red),
      );
    }
  }

  void _downloadBackup(Map<String, dynamic> backup) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('web_downloading_backup'.tr(args: ['${backup['name']}'])), backgroundColor: Colors.blue),
    );
    launchUrl(
      Uri.parse(WebApiService.backupDownloadUrl(backup['id'] as int)),
      webOnlyWindowName: '_blank',
    );
  }

  void _restoreBackup(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_restore_from_backup_title'.tr()),
        content: Text('web_restore_confirm_named'.tr(args: ['${backup['name']}'])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => isRestoring = true);
              final result = await WebApiService.restoreBackup(backup['id'] as int);
              if (!mounted) return;
              setState(() => isRestoring = false);
              if (result != null) {
                await _loadBackups();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('web_restore_completed_restarted'.tr()), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('web_restore_failed'.tr()), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('web_restore_button'.tr()),
          ),
        ],
      ),
    );
  }

  void _deleteBackup(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_delete_backup_title'.tr()),
        content: Text('web_delete_backup_confirm'.tr(args: ['${backup['name']}'])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await WebApiService.deleteBackup(backup['id'] as int);
              if (!mounted) return;
              if (success) {
                setState(() => backups.remove(backup));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('web_backup_deleted'.tr()), backgroundColor: Colors.red),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('web_backup_delete_failed'.tr()), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete_button'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredBackups;

    return Scaffold(
      appBar: AppBar(
        title: Text('web_menu_backup_restore'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Backup Status Cards - CLICKABLE WITH DETAILS
            Row(
              children: [
                _buildStatusCard('web_last_backup'.tr(), lastBackupTime, Icons.backup, Colors.blue, onTap: _showLastBackupDetails),
                const SizedBox(width: 16),
                _buildStatusCard('web_backup_size_label'.tr(), lastBackupSize, Icons.storage, Colors.green, onTap: _showBackupSizeDetails),
                const SizedBox(width: 16),
                _buildStatusCard('web_total_backups'.tr(), backupCount.toString(), Icons.archive, Colors.orange, onTap: _showTotalBackupSummary),
                const SizedBox(width: 16),
                _buildStatusCard('web_backup_status_label'.tr(), _statusLabel(backupStatus), Icons.check_circle, backupStatus == 'Success' ? Colors.green : Colors.red, onTap: _showBackupStatusDetails),
              ],
            ),
            const SizedBox(height: 24),
            
            // Backup Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Text('web_backup_actions_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isBackingUp ? null : _performBackup,
                          icon: isBackingUp
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.backup),
                          label: Text(isBackingUp ? 'web_backing_up'.tr() : 'web_create_full_backup'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56DB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isRestoring
                              ? null
                              : () {
                                  if (backups.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('web_no_backup_found'.tr()), backgroundColor: Colors.red),
                                    );
                                    return;
                                  }
                                  // Restores the most recent backup — the confirmation
                                  // dialog names it explicitly, so this is never a
                                  // "blind" restore even though the button itself
                                  // doesn't ask which backup to use.
                                  _restoreBackup(backups.first);
                                },
                          icon: isRestoring
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.restore),
                          label: Text(isRestoring ? 'web_restoring'.tr() : 'web_restore_from_backup_button'.tr()),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Filter Chips for Backup History
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Text('web_filter_label'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  _buildFilterChip('All', _selectedBackupFilter == 'All', () {
                    setState(() => _selectedBackupFilter = 'All');
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Full', _selectedBackupFilter == 'Full', () {
                    setState(() => _selectedBackupFilter = 'Full');
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Incremental', _selectedBackupFilter == 'Incremental', () {
                    setState(() => _selectedBackupFilter = 'Incremental');
                  }),
                  const Spacer(),
                  Text('web_total_backups_count'.tr(args: ['${filtered.length}']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            
            // Backup History Table
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
                    child: Text('web_backup_history_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 400,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 40,
                        columns: [
                          DataColumn(label: Text('web_backup_name_label'.tr())),
                          DataColumn(label: Text('web_col_datetime'.tr())),
                          DataColumn(label: Text('web_col_size'.tr())),
                          DataColumn(label: Text('web_col_type'.tr())),
                          DataColumn(label: Text('web_col_actions'.tr())),
                        ],
                        rows: filtered.map((backup) {
                          return DataRow(cells: [
                            DataCell(
                              GestureDetector(
                                onTap: () => _showBackupDetails(backup),
                                child: Text(backup['name'], style: const TextStyle(color: Color(0xFF1A56DB), decoration: TextDecoration.underline)),
                              ),
                            ),
                            DataCell(Text(backup['date'])),
                            DataCell(Text(backup['size'])),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: backup['type'] == 'Full' ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(_typeLabel(backup['type'] as String), style: TextStyle(color: backup['type'] == 'Full' ? Colors.green : Colors.blue)),
                            )),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download, size: 18),
                                  onPressed: () => _downloadBackup(backup),
                                  tooltip: 'web_download'.tr(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.restore, size: 18),
                                  onPressed: () => _restoreBackup(backup),
                                  tooltip: 'web_restore_button'.tr(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  onPressed: () => _deleteBackup(backup),
                                  tooltip: 'delete_button'.tr(),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(_typeLabel(label)),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF1A56DB),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}