import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebStaffPerformance extends StatefulWidget {
  const WebStaffPerformance({super.key});

  @override
  State<WebStaffPerformance> createState() => _WebStaffPerformanceState();
}

class _WebStaffPerformanceState extends State<WebStaffPerformance> {
  String selectedPeriod = 'This Week';
  final List<String> periods = ['Today', 'This Week', 'This Month', 'This Year'];

  bool _loading = true;
  List<Map<String, dynamic>> staff = [];

  int _periodToDays(String period) {
    switch (period) {
      case 'Today': return 1;
      case 'This Week': return 7;
      case 'This Month': return 30;
      case 'This Year': return 365;
      default: return 7;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, 2).toUpperCase() : '—';
  }

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  /// Postgres returns COUNT()/NUMERIC aggregates as JSON strings (to avoid
  /// bigint precision loss), not numbers, so this must handle both.
  num? _asNum(dynamic v) => v == null ? null : num.tryParse(v.toString());

  Future<void> _loadPerformance() async {
    setState(() => _loading = true);
    final rows = await WebApiService.getStaffPerformance(days: _periodToDays(selectedPeriod));
    if (!mounted) return;
    setState(() {
      staff = rows.map((r) {
        final name = r['user_name']?.toString() ?? '';
        return {
          'name': name,
          'role': r['role']?.toString() ?? '',
          'completed': _asNum(r['services_completed'])?.toInt() ?? 0,
          'target': _asNum(r['target'])?.toInt() ?? 0,
          'avgTime': _asNum(r['avg_time_minutes'])?.toDouble(),
          'satisfaction': _asNum(r['avg_satisfaction'])?.toDouble(),
          'status': r['status']?.toString() ?? 'Away',
          'avatar': _initials(name),
        };
      }).toList();
      _loading = false;
    });
  }

  int get _totalCompleted => staff.fold(0, (sum, m) => sum + (m['completed'] as int));

  int get _totalTarget => staff.fold(0, (sum, m) => sum + (m['target'] as int));

  String get _completionRateLabel {
    if (_totalTarget == 0) return '—';
    return '${((_totalCompleted / _totalTarget) * 100).clamp(0, 999).toInt()}%';
  }

  String get _avgResponseLabel {
    final withTime = staff.where((m) => m['avgTime'] != null).toList();
    if (withTime.isEmpty) return '—';
    final avg = withTime.fold<double>(0, (sum, m) => sum + (m['avgTime'] as double)) / withTime.length;
    return '${avg.toStringAsFixed(1)}min';
  }

  String get _avgSatisfactionLabel {
    final withRating = staff.where((m) => m['satisfaction'] != null).toList();
    if (withRating.isEmpty) return '—';
    final avg = withRating.fold<double>(0, (sum, m) => sum + (m['satisfaction'] as double)) / withRating.length;
    return avg.toStringAsFixed(1);
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'Today': return 'web_period_today'.tr();
      case 'This Week': return 'web_period_this_week'.tr();
      case 'This Month': return 'web_period_this_month'.tr();
      case 'This Year': return 'web_period_this_year'.tr();
      default: return period;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'Queue Manager': return 'web_role_short_queue_manager'.tr();
      case 'Service Officer': return 'web_role_short_service_officer'.tr();
      case 'Reception': return 'web_role_short_reception'.tr();
      default: return role;
    }
  }

  String _onlineStatusLabel(String status) {
    switch (status) {
      case 'Online': return 'web_online_status'.tr();
      case 'Away': return 'web_away_status'.tr();
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('web_menu_staff_performance'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                const Icon(Icons.notifications_none, color: Colors.grey),
                const SizedBox(width: 16),
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF1A56DB),
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('web_admin_label'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('web_role_admin'.tr(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Period Selector & Summary Stats
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPeriod,
                      items: periods.map((p) => DropdownMenuItem(value: p, child: Text(_periodLabel(p)))).toList(),
                      onChanged: (v) {
                        setState(() => selectedPeriod = v!);
                        _loadPerformance();
                      },
                    ),
                  ),
                ),
                const Spacer(),
                _buildSummaryCard('web_stat_total_services'.tr(), '$_totalCompleted', Icons.assignment, Colors.blue),
                const SizedBox(width: 16),
                _buildSummaryCard('web_stat_avg_response'.tr(), _avgResponseLabel, Icons.timer, Colors.green),
                const SizedBox(width: 16),
                _buildSummaryCard('web_satisfaction_label'.tr(), _avgSatisfactionLabel, Icons.star, Colors.orange),
                const SizedBox(width: 16),
                _buildSummaryCard('web_completion_rate'.tr(), _completionRateLabel, Icons.percent, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            // Staff Performance Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  child: DataTable(
                    columnSpacing: 30,
                    columns: [
                      DataColumn(label: Text('web_staff_member_col'.tr())),
                      DataColumn(label: Text('web_col_role'.tr())),
                      DataColumn(label: Text('web_completed_col'.tr())),
                      DataColumn(label: Text('web_target_col'.tr())),
                      DataColumn(label: Text('web_achievement_col'.tr())),
                      DataColumn(label: Text('web_avg_time_col'.tr())),
                      DataColumn(label: Text('web_satisfaction_label'.tr())),
                      DataColumn(label: Text('web_col_status'.tr())),
                      DataColumn(label: Text('web_performance_col'.tr())),
                    ],
                    rows: staff.map((member) {
                      final target = member['target'] as int;
                      final achievement = target == 0 ? 0.0 : (member['completed'] as int) / target;
                      final performance = achievement.clamp(0.0, 1.0);
                      return DataRow(cells: [
                        DataCell(Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF1A56DB).withOpacity(0.1),
                              child: Text(member['avatar'], style: const TextStyle(color: Color(0xFF1A56DB))),
                            ),
                            const SizedBox(width: 12),
                            Text(member['name']),
                          ],
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_roleLabel(member['role'] as String), style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(Text('${member['completed']}')),
                        DataCell(Text('${member['target']}')),
                        DataCell(Text('${(achievement * 100).toInt()}%', style: TextStyle(
                          color: achievement >= 1.0 ? Colors.green : (achievement >= 0.8 ? Colors.orange : Colors.red),
                          fontWeight: FontWeight.bold,
                        ))),
                        DataCell(Text(member['avgTime'] != null ? '${(member['avgTime'] as double).toStringAsFixed(1)} min' : '—')),
                        DataCell(Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(member['satisfaction'] != null ? (member['satisfaction'] as double).toStringAsFixed(1) : '—'),
                          ],
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: member['status'] == 'Online' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _onlineStatusLabel(member['status'] as String),
                            style: TextStyle(color: member['status'] == 'Online' ? Colors.green : Colors.orange),
                          ),
                        )),
                        DataCell(SizedBox(
                          width: 100,
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: performance,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A56DB)),
                              ),
                              const SizedBox(height: 4),
                              Text('${(performance * 100).toInt()}%', style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        )),
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}