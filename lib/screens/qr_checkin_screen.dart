import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/models/appointment_model.dart';
import 'package:queuenova_mobile/services/appointment_service.dart';

class QRCheckInScreen extends StatefulWidget {
  const QRCheckInScreen({super.key});

  @override
  State<QRCheckInScreen> createState() => _QRCheckInScreenState();
}

class _QRCheckInScreenState extends State<QRCheckInScreen> {
  String selectedAppointmentId = '';
  List<AppointmentModel> appointments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => isLoading = true);
    final apts = await AppointmentService.getAppointments();
    setState(() {
      appointments = apts.where((a) => a.status == 'Confirmed').toList();
      if (appointments.isNotEmpty) {
        selectedAppointmentId = appointments[0].id;
      }
      isLoading = false;
    });
  }

  AppointmentModel? get selectedAppointment {
    try {
      return appointments.firstWhere((a) => a.id == selectedAppointmentId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedApt = selectedAppointment;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('my_qr_code'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : appointments.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.offWhite,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedAppointmentId,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                            items: appointments.map((apt) {
                              return DropdownMenuItem(
                                value: apt.id,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(apt.service, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    Text(
                                      '${DateFormat('dd MMM yyyy').format(apt.date)} • ${apt.time}',
                                      style: TextStyle(fontSize: 11, color: AppColors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => selectedAppointmentId = value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      if (selectedApt != null)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5)),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                child: QrImageView(
                                  data: selectedApt.qrData,
                                  version: QrVersions.auto,
                                  size: 200,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('show_qr_at_center'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      
                      if (selectedApt != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow('qr_detail_service_label'.tr(), selectedApt.service),
                              const Divider(height: 24),
                              _buildDetailRow('qr_detail_office_label'.tr(), selectedApt.office),
                              const Divider(height: 24),
                              _buildDetailRow('qr_detail_date_label'.tr(), DateFormat('dd MMM yyyy').format(selectedApt.date)),
                              const Divider(height: 24),
                              _buildDetailRow('qr_detail_time_label'.tr(), selectedApt.time),
                              const Divider(height: 24),
                              _buildDetailRow('qr_detail_token_label'.tr(), selectedApt.token),
                              const Divider(height: 24),
                              _buildDetailRow('qr_detail_status_label'.tr(), selectedApt.status),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('how_to_use'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('qr_instructions'.tr(), style: const TextStyle(fontSize: 12)),
                                ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code, size: 80, color: AppColors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('no_upcoming_appointments'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('book_appointment_get_qr'.tr(), style: TextStyle(fontSize: 14, color: AppColors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.calendar_today),
            label: Text('book_appointment'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}