import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebSystemHealth extends StatefulWidget {
  const WebSystemHealth({super.key});

  @override
  State<WebSystemHealth> createState() => _WebSystemHealthState();
}

class _WebSystemHealthState extends State<WebSystemHealth> {
  bool autoRefresh = false;
  bool _loading = true;
  String overallStatus = 'Operational';
  String uptime = '—';
  String uptime24hLabel = '—';
  Timer? _autoRefreshTimer;

  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> systemMetrics = [];
  List<Map<String, dynamic>> alerts = [];

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  num? _asNum(dynamic v) => v == null ? null : num.tryParse(v.toString());

  Future<void> _loadHealth() async {
    final health = await WebApiService.getSystemHealth();
    final logs = await WebApiService.getAuditLogs(limit: 5);
    if (!mounted) return;

    if (health != null) {
      final cpuPercent = _asNum(health['cpuPercent'])?.toDouble() ?? 0;
      final memUsedMb = _asNum(health['memoryUsedMb'])?.toInt() ?? 0;
      final memTotalMb = _asNum(health['memoryTotalMb'])?.toInt() ?? 0;
      final diskPercent = _asNum(health['diskUsedPercent'])?.toDouble();
      final activeSessions = _asNum(health['activeSessions'])?.toInt() ?? 0;
      final requestsPerMin = _asNum(health['requestsPerMin'])?.toInt() ?? 0;
      final overallUptime24h = _asNum(health['overallUptime24h'])?.toDouble();
      final overallUptime30d = _asNum(health['overallUptime30d'])?.toDouble();

      setState(() {
        overallStatus = health['status']?.toString() ?? 'Operational';
        uptime = overallUptime30d != null ? '${overallUptime30d.toStringAsFixed(1)}%' : 'web_no_data_yet'.tr();
        uptime24hLabel = overallUptime24h != null ? '${overallUptime24h.toStringAsFixed(1)}%' : 'web_no_data_yet'.tr();

        systemMetrics = [
          {'metric': 'CPU Usage', 'value': '${cpuPercent.toStringAsFixed(0)}%', 'status': cpuPercent > 80 ? 'Warning' : 'Good', 'icon': Icons.memory, 'color': cpuPercent > 80 ? Colors.orange : Colors.green},
          {'metric': 'Memory Usage', 'value': '${(memUsedMb / 1024).toStringAsFixed(1)} GB / ${(memTotalMb / 1024).toStringAsFixed(1)} GB', 'status': memTotalMb > 0 && memUsedMb / memTotalMb > 0.85 ? 'Warning' : 'Good', 'icon': Icons.sd_storage, 'color': memTotalMb > 0 && memUsedMb / memTotalMb > 0.85 ? Colors.orange : Colors.green},
          {'metric': 'Disk Space', 'value': diskPercent != null ? '${diskPercent.toStringAsFixed(0)}% used' : 'web_no_data_yet'.tr(), 'status': (diskPercent ?? 0) > 80 ? 'Warning' : 'Good', 'icon': Icons.storage, 'color': (diskPercent ?? 0) > 80 ? Colors.orange : Colors.green},
          {'metric': 'Active Sessions', 'value': '$activeSessions', 'status': 'Good', 'icon': Icons.people, 'color': Colors.green},
          {'metric': 'API Requests/min', 'value': '$requestsPerMin', 'status': 'Good', 'icon': Icons.api, 'color': Colors.green},
        ];

        final rawServices = (health['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        services = rawServices.map((s) {
          final healthy = s['healthy'] == true;
          final responseMs = _asNum(s['responseMs'])?.toInt();
          final svcUptime = _asNum(s['uptime24h'])?.toDouble();
          return {
            'name': s['name']?.toString() ?? '',
            'status': healthy ? 'Healthy' : 'Degraded',
            'uptime': svcUptime != null ? '${svcUptime.toStringAsFixed(1)}%' : '—',
            'response': responseMs != null ? '${responseMs}ms' : '—',
            'lastCheck': 'web_just_now'.tr(),
          };
        }).toList();

        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }

    setState(() {
      alerts = logs.take(5).map((log) {
        final action = log['action']?.toString() ?? '';
        final isWarning = action.contains('failed') || action.contains('blocked') || action.contains('delete') || action.contains('reject');
        final isSuccess = action.contains('create') || action.contains('approve') || action.contains('backup');
        return {
          'type': isWarning ? 'Warning' : (isSuccess ? 'Success' : 'Info'),
          'title': _prettify(action),
          'description': log['details']?.toString().isNotEmpty == true ? log['details'].toString() : action,
          'time': _relativeTime(log['created_at']?.toString()),
          'color': isWarning ? Colors.orange : (isSuccess ? Colors.green : Colors.blue),
        };
      }).toList();
    });
  }

  String _prettify(String raw) => raw
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'web_just_now'.tr();
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${'web_min_ago'.tr()}';
    if (diff.inHours < 24) return '${diff.inHours} ${(diff.inHours > 1 ? 'web_hours_ago' : 'web_hour_ago').tr()}';
    return '${diff.inDays} ${(diff.inDays > 1 ? 'web_days_ago' : 'web_day_ago').tr()}';
  }

  void _refreshStatus() {
    _loadHealth();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('web_system_status_refreshed'.tr()), backgroundColor: Colors.green),
    );
  }

  void _setAutoRefresh(bool value) {
    setState(() => autoRefresh = value);
    _autoRefreshTimer?.cancel();
    if (value) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadHealth());
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Operational': return 'web_status_operational'.tr();
      case 'Healthy': return 'web_status_healthy'.tr();
      case 'Degraded': return 'web_status_degraded'.tr();
      default: return status;
    }
  }

  String _metricLabel(String metric) {
    switch (metric) {
      case 'CPU Usage': return 'web_metric_cpu_usage'.tr();
      case 'Memory Usage': return 'web_metric_memory_usage'.tr();
      case 'Disk Space': return 'web_metric_disk_space'.tr();
      case 'Active Sessions': return 'web_metric_active_sessions'.tr();
      case 'API Requests/min': return 'web_metric_api_requests'.tr();
      default: return metric;
    }
  }

  String _serviceLabel(String name) {
    switch (name) {
      case 'Database Server': return 'web_service_database_server'.tr();
      case 'API Gateway': return 'web_service_api_gateway'.tr();
      case 'Notification Service': return 'web_service_notification'.tr();
      case 'QR Service': return 'web_service_qr'.tr();
      case 'File Storage': return 'web_service_file_storage'.tr();
      default: return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('web_system_health_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Switch(
            value: autoRefresh,
            onChanged: _setAutoRefresh,
            activeColor: const Color(0xFF1A56DB),
          ),
          Text('web_auto_refresh'.tr(), style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 20),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
            tooltip: 'web_refresh_tooltip'.tr(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Overall Health Status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 50),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('web_system_status_label'.tr(args: [_statusLabel(overallStatus)]), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('web_all_systems_normal'.tr(args: [uptime]), style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('web_last_24h_uptime'.tr(args: [uptime24hLabel]), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // System Metrics
            Text('web_system_metrics_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: systemMetrics.map((metric) => _buildMetricCard(metric)).toList(),
            ),
            const SizedBox(height: 24),
            
            // Service Status
            Text('web_service_status_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 40,
                  columns: [
                    DataColumn(label: Text('web_col_service_name'.tr())),
                    DataColumn(label: Text('web_col_status'.tr())),
                    DataColumn(label: Text('web_col_uptime'.tr())),
                    DataColumn(label: Text('web_col_response_time'.tr())),
                    DataColumn(label: Text('web_col_last_check'.tr())),
                  ],
                  rows: services.map((service) {
                    final isHealthy = service['status'] == 'Healthy';
                    return DataRow(cells: [
                      DataCell(Text(_serviceLabel(service['name'] as String), style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isHealthy ? Colors.green : Colors.orange).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_statusLabel(service['status'] as String), style: TextStyle(color: isHealthy ? Colors.green : Colors.orange)),
                      )),
                      DataCell(Text(service['uptime'])),
                      DataCell(Text(service['response'])),
                      DataCell(Text(service['lastCheck'])),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Recent Alerts
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
                    child: Text('web_recent_alerts'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ...alerts.map((alert) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: alert['color'],
                      child: Icon(
                        alert['type'] == 'Warning' ? Icons.warning : (alert['type'] == 'Success' ? Icons.check : Icons.info),
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    title: Text(alert['title']),
                    subtitle: Text(alert['description']),
                    trailing: Text(alert['time']),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(metric['icon'], size: 32, color: metric['color']),
          const SizedBox(height: 8),
          Text(_metricLabel(metric['metric'] as String), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(metric['value'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: metric['color'])),
        ],
      ),
    );
  }
}