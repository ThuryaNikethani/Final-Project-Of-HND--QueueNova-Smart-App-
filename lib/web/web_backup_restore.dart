import 'package:flutter/material.dart';

class WebBackupRestore extends StatefulWidget {
  const WebBackupRestore({super.key});

  @override
  State<WebBackupRestore> createState() => _WebBackupRestoreState();
}

class _WebBackupRestoreState extends State<WebBackupRestore> {
  bool isBackingUp = false;
  bool isRestoring = false;
  String lastBackupTime = '2026-05-21 10:30:45';
  String lastBackupSize = '2.4 MB';
  int backupCount = 12;
  String backupStatus = 'Success';
  String _selectedBackupFilter = 'All';

  List<Map<String, dynamic>> backups = [
    {'name': 'full_backup_20260521_103045.zip', 'date': '2026-05-21 10:30:45', 'size': '2.4 MB', 'type': 'Full', 'status': 'Success'},
    {'name': 'full_backup_20260520_120000.zip', 'date': '2026-05-20 12:00:00', 'size': '2.3 MB', 'type': 'Full', 'status': 'Success'},
    {'name': 'incremental_backup_20260519_180000.zip', 'date': '2026-05-19 18:00:00', 'size': '0.5 MB', 'type': 'Incremental', 'status': 'Success'},
    {'name': 'full_backup_20260518_090000.zip', 'date': '2026-05-18 09:00:00', 'size': '2.2 MB', 'type': 'Full', 'status': 'Success'},
    {'name': 'full_backup_20260517_140000.zip', 'date': '2026-05-17 14:00:00', 'size': '2.1 MB', 'type': 'Full', 'status': 'Success'},
    {'name': 'incremental_backup_20260516_220000.zip', 'date': '2026-05-16 22:00:00', 'size': '0.4 MB', 'type': 'Incremental', 'status': 'Success'},
    {'name': 'full_backup_20260515_080000.zip', 'date': '2026-05-15 08:00:00', 'size': '2.0 MB', 'type': 'Full', 'status': 'Success'},
    {'name': 'full_backup_20260514_160000.zip', 'date': '2026-05-14 16:00:00', 'size': '2.0 MB', 'type': 'Full', 'status': 'Success'},
    {'name': 'incremental_backup_20260513_120000.zip', 'date': '2026-05-13 12:00:00', 'size': '0.3 MB', 'type': 'Incremental', 'status': 'Success'},
    {'name': 'full_backup_20260512_090000.zip', 'date': '2026-05-12 09:00:00', 'size': '1.9 MB', 'type': 'Full', 'status': 'Success'},
    {'name': 'full_backup_20260511_110000.zip', 'date': '2026-05-11 11:00:00', 'size': '1.9 MB', 'type': 'Full', 'status': 'Success'},
    {'name': 'full_backup_20260510_070000.zip', 'date': '2026-05-10 07:00:00', 'size': '1.8 MB', 'type': 'Full', 'status': 'Success'},
  ];

  List<Map<String, dynamic>> get filteredBackups {
    if (_selectedBackupFilter == 'All') return backups;
    if (_selectedBackupFilter == 'Full') return backups.where((b) => b['type'] == 'Full').toList();
    if (_selectedBackupFilter == 'Incremental') return backups.where((b) => b['type'] == 'Incremental').toList();
    return backups;
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
            const Text('Backup Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Backup Name', backup['name']),
            const Divider(),
            _buildDetailRow('Date & Time', backup['date']),
            const Divider(),
            _buildDetailRow('File Size', backup['size']),
            const Divider(),
            _buildDetailRow('Backup Type', backup['type']),
            const Divider(),
            _buildDetailRow('Status', backup['status']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadBackup(backup);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download'),
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
        const SnackBar(content: Text('No backup found'), backgroundColor: Colors.red),
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
            const Text('Backup Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('Total Backups', '$backupCount'),
            const Divider(),
            _buildSummaryRow('Full Backups', '$fullBackups'),
            const Divider(),
            _buildSummaryRow('Incremental Backups', '$incrementalBackups'),
            const Divider(),
            _buildSummaryRow('Total Storage Used', '${totalSize.toStringAsFixed(1)} MB'),
            const Divider(),
            _buildSummaryRow('Oldest Backup', backups.last['date']),
            const Divider(),
            _buildSummaryRow('Latest Backup', backups.first['date']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedBackupFilter = 'All';
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: const Text('View All'),
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
            const Text('Backup Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Current Status', backupStatus, backupStatus == 'Success' ? Colors.green : Colors.red),
            const Divider(),
            _buildStatusRow('Successful Backups', '$successfulBackups', Colors.green),
            const Divider(),
            _buildStatusRow('Failed Backups', '$failedBackups', failedBackups > 0 ? Colors.red : Colors.grey),
            const Divider(),
            _buildStatusRow('Last Backup Time', lastBackupTime, Colors.blue),
            const Divider(),
            _buildStatusRow('Last Backup Size', lastBackupSize, Colors.blue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
    final totalSize = backups.fold<double>(0, (sum, b) {
      double size = double.tryParse(b['size'].replaceAll(' MB', '')) ?? 0;
      return sum + size;
    });
    final avgSize = totalSize / backups.length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.storage, color: Colors.green),
            const SizedBox(width: 10),
            const Text('Storage Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSizeRow('Total Storage Used', '${totalSize.toStringAsFixed(1)} MB', Colors.purple),
            const Divider(),
            _buildSizeRow('Average Backup Size', '${avgSize.toStringAsFixed(1)} MB', Colors.blue),
            const Divider(),
            _buildSizeRow('Largest Backup', '2.5 MB', Colors.orange),
            const Divider(),
            _buildSizeRow('Smallest Backup', '0.3 MB', Colors.green),
            const Divider(),
            _buildSizeRow('Available Space', '28.5 GB', Colors.teal),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
    setState(() {
      isBackingUp = true;
      backupStatus = 'In Progress';
    });
    
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      isBackingUp = false;
      backupCount++;
      backupStatus = 'Success';
      lastBackupTime = DateTime.now().toString().substring(0, 19).replaceAll('T', ' ');
      lastBackupSize = '2.5 MB';
      
      backups.insert(0, {
        'name': 'full_backup_${DateTime.now().toString().substring(0, 19).replaceAll(':', '').replaceAll('-', '').replaceAll('T', '_')}.zip',
        'date': lastBackupTime,
        'size': '2.5 MB',
        'type': 'Full',
        'status': 'Success',
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup completed successfully'), backgroundColor: Colors.green),
    );
  }

  void _downloadBackup(Map<String, dynamic> backup) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${backup['name']}...'), backgroundColor: Colors.blue),
    );
  }

  void _restoreBackup(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restore from Backup'),
        content: Text('Are you sure you want to restore from ${backup['name']}? This will overwrite all current data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => isRestoring = true);
              await Future.delayed(const Duration(seconds: 2));
              setState(() => isRestoring = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restore completed. System restarted.'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore'),
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
        title: const Text('Delete Backup'),
        content: Text('Are you sure you want to delete ${backup['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                backups.remove(backup);
                backupCount--;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup deleted'), backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
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
        title: const Text('Backup & Restore'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Backup Status Cards - CLICKABLE WITH DETAILS
            Row(
              children: [
                _buildStatusCard('Last Backup', lastBackupTime, Icons.backup, Colors.blue, onTap: _showLastBackupDetails),
                const SizedBox(width: 16),
                _buildStatusCard('Backup Size', lastBackupSize, Icons.storage, Colors.green, onTap: _showBackupSizeDetails),
                const SizedBox(width: 16),
                _buildStatusCard('Total Backups', backupCount.toString(), Icons.archive, Colors.orange, onTap: _showTotalBackupSummary),
                const SizedBox(width: 16),
                _buildStatusCard('Backup Status', backupStatus, Icons.check_circle, backupStatus == 'Success' ? Colors.green : Colors.red, onTap: _showBackupStatusDetails),
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
                  const Text('Backup Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isBackingUp ? null : _performBackup,
                          icon: isBackingUp 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                              : const Icon(Icons.backup),
                          label: Text(isBackingUp ? 'Backing up...' : 'Create Full Backup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56DB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('Restore from Backup'),
                                content: const Text('This will overwrite all current data. Are you sure you want to continue?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      setState(() => isRestoring = true);
                                      Navigator.pop(context);
                                      await Future.delayed(const Duration(seconds: 2));
                                      setState(() => isRestoring = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Restore completed.'), backgroundColor: Colors.green),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Restore'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: isRestoring 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                              : const Icon(Icons.restore),
                          label: Text(isRestoring ? 'Restoring...' : 'Restore from Backup'),
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
                  const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w500)),
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
                  Text('Total: ${filtered.length} backups', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Backup History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 400,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 40,
                        columns: const [
                          DataColumn(label: Text('Backup Name')),
                          DataColumn(label: Text('Date & Time')),
                          DataColumn(label: Text('Size')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Actions')),
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
                              child: Text(backup['type'], style: TextStyle(color: backup['type'] == 'Full' ? Colors.green : Colors.blue)),
                            )),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download, size: 18),
                                  onPressed: () => _downloadBackup(backup),
                                  tooltip: 'Download',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.restore, size: 18),
                                  onPressed: () => _restoreBackup(backup),
                                  tooltip: 'Restore',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  onPressed: () => _deleteBackup(backup),
                                  tooltip: 'Delete',
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
      label: Text(label),
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