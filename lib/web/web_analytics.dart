
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_api_service.dart';

class WebAnalytics extends StatefulWidget {
  const WebAnalytics({super.key});

  @override
  State<WebAnalytics> createState() => _WebAnalyticsState();
}

class _WebAnalyticsState extends State<WebAnalytics> {
  bool _loading = true;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _queueTrends = [];
  List<Map<String, dynamic>> _topServices = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final results = await Future.wait([
      WebApiService.getDashboardStats(),
      WebApiService.getQueueTrends(days: 7),
      WebApiService.getAnalyticsOverview(),
    ]);
    if (!mounted) return;
    final overview = results[2] as Map<String, dynamic>?;
    setState(() {
      _stats = results[0] as Map<String, dynamic>?;
      _queueTrends = results[1] as List<Map<String, dynamic>>;
      _topServices = (overview?['topServices'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _loading = false;
    });
  }

  String _statValue(String key, {String suffix = ''}) {
    final v = _stats?[key];
    if (v == null) return '—';
    if (v is num) {
      if (v == v.roundToDouble()) return '${v.toInt()}$suffix';
      return '${v.toStringAsFixed(1)}$suffix';
    }
    return '$v$suffix';
  }

  int _asInt(dynamic v) => v == null ? 0 : (num.tryParse(v.toString())?.toInt() ?? 0);

  String _weekdayLabel(String? isoDate) {
    if (isoDate == null) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[dt.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('web_menu_analytics'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildStatCard('web_stat_total_citizens'.tr(), _statValue('totalCitizens'), Icons.people)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('web_stat_services_completed'.tr(), _statValue('completedServices'), Icons.check_circle)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('web_stat_avg_satisfaction'.tr(), _statValue('avgSatisfaction'), Icons.star)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('web_stat_avg_response'.tr(), _statValue('avgResponseMinutes', suffix: 'min'), Icons.timer)),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('web_daily_service_volume'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _queueTrends.isEmpty
                                ? Center(child: Text('web_chart_placeholder'.tr()))
                                : _buildDailyVolumeChart(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('web_popular_services'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _topServices.isEmpty
                                ? Center(child: Text('web_popular_services_chart_placeholder'.tr()))
                                : _buildPopularServicesChart(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyVolumeChart() {
    final maxTotal = _queueTrends
        .map((t) => _asInt(t['total']))
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _queueTrends.map((t) {
        final total = _asInt(t['total']);
        final heightFraction = maxTotal == 0 ? 0.0 : total / maxTotal;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('$total', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: heightFraction.clamp(0.03, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56DB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(_weekdayLabel(t['date']?.toString()), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPopularServicesChart() {
    final maxCount = _topServices
        .map((s) => _asInt(s['count']))
        .fold<int>(0, (a, b) => a > b ? a : b);
    return ListView.separated(
      itemCount: _topServices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = _topServices[index];
        final count = _asInt(service['count']);
        final widthFraction = maxCount == 0 ? 0.0 : count / maxCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(service['service']?.toString() ?? '—', style: const TextStyle(fontSize: 13)),
                Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widthFraction.clamp(0.02, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A56DB)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey)),
              Icon(icon, color: const Color(0xFF1A56DB)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
