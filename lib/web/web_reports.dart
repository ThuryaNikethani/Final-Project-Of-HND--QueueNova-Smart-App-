import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'web_api_service.dart';

class WebReports extends StatefulWidget {
  const WebReports({super.key});

  @override
  State<WebReports> createState() => _WebReportsState();
}

class _WebReportsState extends State<WebReports> {
  String selectedReportType = 'Daily';
  DateTime selectedDate = DateTime.now();
  bool _generating = false;
  bool _loadingReports = true;
  List<Map<String, dynamic>> _reports = [];

  final List<String> reportTypes = ['Daily', 'Weekly', 'Monthly'];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reports = await WebApiService.getReports();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _loadingReports = false;
    });
  }

  Future<void> _generateReport() async {
    setState(() => _generating = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('web_report_generation_started'.tr()),
        backgroundColor: Colors.green,
      ),
    );
    final report = await WebApiService.generateReport(
      reportType: selectedReportType,
      date: selectedDate,
    );
    if (!mounted) return;
    setState(() => _generating = false);
    if (report != null) {
      await _loadReports();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('web_report_generation_failed'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _downloadReport(int id, String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('web_downloading_file'.tr(args: [fileName])),
        backgroundColor: Colors.green,
      ),
    );
    launchUrl(
      Uri.parse(WebApiService.reportDownloadUrl(id)),
      webOnlyWindowName: '_blank',
    );
  }

  String _formatGeneratedDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('web_menu_reports'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Left Panel - Generate Report
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'web_generate_report'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'web_report_type'.tr(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedReportType,
                          isExpanded: true,
                          items: reportTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedReportType = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'web_date_range'.tr(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _generating ? null : _generateReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56DB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _generating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text('web_generate_report'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Right Panel - Recent Reports
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'web_recent_reports'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loadingReports
                          ? const Center(child: CircularProgressIndicator())
                          : _reports.isEmpty
                              ? Center(child: Text('web_no_reports_yet'.tr()))
                              : ListView.builder(
                                  itemCount: _reports.length,
                                  itemBuilder: (context, index) {
                                    final report = _reports[index];
                                    final fileName = report['file_name']?.toString() ?? 'Report.pdf';
                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                      ),
                                      title: Text(fileName),
                                      subtitle: Text('web_generated_on'.tr(args: [_formatGeneratedDate(report['generated_at']?.toString())])),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.download),
                                        onPressed: () => _downloadReport(report['id'] as int, fileName),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}