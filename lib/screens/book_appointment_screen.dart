import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/models/appointment_model.dart';
import 'package:queuenova_mobile/services/appointment_service.dart';
import 'package:queuenova_mobile/services/office_settings_service.dart';
import 'package:queuenova_mobile/screens/payment_screen.dart';

const Map<String, String> _kBookServiceKeys = {
  'Passport Renewal': 'svc_passport_renewal_name',
  'New Passport Application': 'svc_new_passport_name',
  'National ID Card': 'svc_national_id_name',
  'NIC Replacement': 'svc_nic_replacement_name',
  'Driving License': 'svc_driving_license_name',
  'License Renewal': 'svc_license_renewal_name',
  'Birth Certificate': 'svc_birth_certificate_name',
  'Marriage Certificate': 'svc_marriage_certificate_name',
  'Death Certificate': 'svc_death_certificate_name',
  'Police Clearance': 'svc_police_clearance_name',
  'Visa Services': 'svc_visa_services_name',
  'Land Registration': 'svc_land_registration_name',
};

const Map<String, String> _kPayMethodKeys = {
  'Pay at Counter': 'pay_at_counter',
  'Pay Online': 'pay_online',
};

const Map<String, String> _kBookOfficeKeys = {
  'Divisional Secretariat - Colombo': 'office_divisional_secretariat_colombo',
  'Divisional Secretariat - Kandy': 'office_divisional_secretariat_kandy',
  'Divisional Secretariat - Galle': 'office_ds_galle',
  'Divisional Secretariat - Kurunegala': 'office_ds_kurunegala',
  'RMV - Werahera': 'office_rmv_werahera',
  'RMV - Kiribathgoda': 'office_rmv_kiribathgoda',
  'RMV - Kandy': 'office_rmv_kandy',
  'Passport Office - Battaramulla': 'office_passport_battaramulla',
  'Passport Office - Kandy': 'office_passport_kandy',
  'Department of Registration - Colombo': 'office_dept_registration_colombo',
  'NIC Service Center - Colombo': 'office_nic_center_colombo',
  'NIC Service Center - Kandy': 'office_nic_center_kandy',
  'Immigration Department - Battaramulla': 'office_immigration_battaramulla',
  'Land Registry Office - Colombo': 'office_land_registry_colombo',
  'Land Registry Office - Kandy': 'office_land_registry_kandy',
  'Municipal Council - Colombo': 'office_municipal_council_colombo',
  'Municipal Council - Kandy': 'office_municipal_council_kandy',
  'Registrar General Department - Colombo': 'office_registrar_general_colombo',
};

class BookAppointmentScreen extends StatefulWidget {
  final AppointmentModel? rescheduleAppointment;
  final String? preSelectedOffice;

  const BookAppointmentScreen({
    super.key,
    this.rescheduleAppointment,
    this.preSelectedOffice,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  String selectedService = 'Passport Renewal';
  String selectedOffice = 'Divisional Secretariat - Colombo';
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  String selectedPaymentMethod = 'Pay at Counter';
  final TextEditingController _notesController = TextEditingController();
  bool _isBooking = false;
  bool _isReschedule = false;
  double _selectedFee = 5000;
  Map<String, dynamic>? _officeAvailability;
  bool _isTimeValid = true;
  bool _availabilityLoading = false;

  bool get _canBook {
    if (_availabilityLoading) return false;
    if (_officeAvailability == null) return true;
    final isOpen = _officeAvailability!['isWorking'] as bool;
    return isOpen && _isTimeValid;
  }

  // Document upload variables
  Map<String, File> _selectedFiles = {};
  Map<String, String> _selectedFileNames = {};
  Map<String, bool> _isFileUploading = {};

  // Dynamic document requirements based on service
  List<DocumentRequirement> get _requiredDocs {
    switch (selectedService) {
      case 'Passport Renewal':
      case 'New Passport Application':
        return [
          DocumentRequirement(
            id: 'old_passport',
            name: 'Old Passport',
            nameKey: 'doc_old_passport',
            description: 'Previous passport (if available)',
            descKey: 'doc_old_passport_desc',
            icon: Icons.airplane_ticket_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            nameKey: 'doc_passport_photo',
            description: 'Recent passport size photo (white background)',
            descKey: 'doc_passport_photo_white_bg_desc',
            icon: Icons.photo_camera_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            nameKey: 'svc_national_id_name',
            description: 'Copy of your NIC',
            descKey: 'doc_nic_copy_desc',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'proof_of_address',
            name: 'Proof of Address',
            nameKey: 'doc_proof_of_address',
            description: 'Utility bill or bank statement',
            descKey: 'doc_proof_of_address_desc',
            icon: Icons.home_outlined,
            required: false,
            selected: false,
          ),
        ];
      case 'National ID Card':
      case 'NIC Replacement':
        return [
          DocumentRequirement(
            id: 'birth_certificate',
            name: 'Birth Certificate',
            nameKey: 'svc_birth_certificate_name',
            description: 'Copy of birth certificate',
            descKey: 'doc_birth_cert_copy_desc',
            icon: Icons.celebration_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'proof_of_address',
            name: 'Proof of Address',
            nameKey: 'doc_proof_of_address',
            description: 'Utility bill or bank statement',
            descKey: 'doc_proof_of_address_desc',
            icon: Icons.home_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'police_report',
            name: 'Police Report',
            nameKey: 'doc_police_report',
            description: 'For lost NIC replacement',
            descKey: 'doc_police_report_desc',
            icon: Icons.report_outlined,
            required: false,
            selected: false,
          ),
        ];
      case 'Driving License':
        return [
          DocumentRequirement(
            id: 'medical_certificate',
            name: 'Medical Certificate',
            nameKey: 'doc_medical_certificate',
            description: 'Medical fitness certificate',
            descKey: 'doc_medical_fitness_desc',
            icon: Icons.health_and_safety_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            nameKey: 'svc_national_id_name',
            description: 'Copy of your NIC',
            descKey: 'doc_nic_copy_desc',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            nameKey: 'doc_passport_photo',
            description: 'Recent passport size photo',
            descKey: 'doc_passport_photo_desc',
            icon: Icons.photo_camera_outlined,
            required: false,
            selected: false,
          ),
        ];
      case 'License Renewal':
        return [
          DocumentRequirement(
            id: 'old_license',
            name: 'Old Driving License',
            nameKey: 'doc_old_license',
            description: 'Previous driving license',
            descKey: 'doc_old_license_desc',
            icon: Icons.directions_car_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            nameKey: 'svc_national_id_name',
            description: 'Copy of your NIC',
            descKey: 'doc_nic_copy_desc',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            nameKey: 'doc_passport_photo',
            description: 'Recent passport size photo',
            descKey: 'doc_passport_photo_desc',
            icon: Icons.photo_camera_outlined,
            required: false,
            selected: false,
          ),
        ];
      case 'Birth Certificate':
        return [
          DocumentRequirement(
            id: 'parents_nic',
            name: 'Parents NIC',
            nameKey: 'doc_parents_nic',
            description: 'NIC of both parents',
            descKey: 'doc_parents_nic_desc',
            icon: Icons.people_outline,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'hospital_record',
            name: 'Hospital Birth Record',
            nameKey: 'doc_hospital_birth_record',
            description: 'Birth record from hospital',
            descKey: 'doc_hospital_birth_record_desc',
            icon: Icons.local_hospital_outlined,
            required: false,
            selected: false,
          ),
        ];
      case 'Marriage Certificate':
        return [
          DocumentRequirement(
            id: 'parties_nic',
            name: 'NIC of Both Parties',
            nameKey: 'doc_parties_nic',
            description: 'NIC of bride and groom',
            descKey: 'doc_parties_nic_desc',
            icon: Icons.people_outline,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'birth_certificates',
            name: 'Birth Certificates',
            nameKey: 'doc_birth_certificates',
            description: 'Birth certificates of both parties',
            descKey: 'doc_birth_certificates_desc',
            icon: Icons.celebration_outlined,
            required: false,
            selected: false,
          ),
        ];
      case 'Death Certificate':
        return [
          DocumentRequirement(
            id: 'medical_certificate',
            name: 'Medical Certificate',
            nameKey: 'doc_medical_certificate',
            description: 'Medical certificate of death',
            descKey: 'doc_medical_death_desc',
            icon: Icons.health_and_safety_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'deceased_nic',
            name: 'Deceased NIC',
            nameKey: 'doc_deceased_nic',
            description: 'NIC of the deceased',
            descKey: 'doc_deceased_nic_desc',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
        ];
      case 'Police Clearance':
        return [
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            nameKey: 'svc_national_id_name',
            description: 'Copy of your NIC',
            descKey: 'doc_nic_copy_desc',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            nameKey: 'doc_passport_photo',
            description: 'Recent passport size photo',
            descKey: 'doc_passport_photo_desc',
            icon: Icons.photo_camera_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'proof_of_address',
            name: 'Proof of Address',
            nameKey: 'doc_proof_of_address',
            description: 'Utility bill or bank statement',
            descKey: 'doc_proof_of_address_desc',
            icon: Icons.home_outlined,
            required: false,
            selected: false,
          ),
        ];
      case 'Visa Services':
        return [
          DocumentRequirement(
            id: 'passport',
            name: 'Passport',
            nameKey: 'passport',
            description: 'Current passport copy',
            descKey: 'doc_current_passport_desc',
            icon: Icons.airplane_ticket_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            nameKey: 'doc_passport_photo',
            description: 'Recent passport size photo',
            descKey: 'doc_passport_photo_desc',
            icon: Icons.photo_camera_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'proof_of_address',
            name: 'Proof of Address',
            nameKey: 'doc_proof_of_address',
            description: 'Utility bill or bank statement',
            descKey: 'doc_proof_of_address_desc',
            icon: Icons.home_outlined,
            required: false,
            selected: false,
          ),
        ];
      case 'Land Registration':
        return [
          DocumentRequirement(
            id: 'deed',
            name: 'Deed',
            nameKey: 'doc_deed',
            description: 'Original land deed',
            descKey: 'doc_deed_desc',
            icon: Icons.description_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            nameKey: 'svc_national_id_name',
            description: 'Copy of your NIC',
            descKey: 'doc_nic_copy_desc',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'survey_plan',
            name: 'Survey Plan',
            nameKey: 'doc_survey_plan',
            description: 'Land survey plan',
            descKey: 'doc_survey_plan_desc',
            icon: Icons.map_outlined,
            required: false,
            selected: false,
          ),
        ];
      default:
        return [
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            nameKey: 'svc_national_id_name',
            description: 'Copy of your NIC',
            descKey: 'doc_nic_copy_desc',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
        ];
    }
  }

  final List<String> services = [
    'Passport Renewal',
    'New Passport Application',
    'National ID Card',
    'NIC Replacement',
    'Driving License',
    'License Renewal',
    'Birth Certificate',
    'Marriage Certificate',
    'Death Certificate',
    'Police Clearance',
    'Visa Services',
    'Land Registration',
  ];

  final List<String> offices = [
    'Divisional Secretariat - Colombo',
    'Divisional Secretariat - Kandy',
    'Divisional Secretariat - Galle',
    'Divisional Secretariat - Kurunegala',
    'RMV - Werahera',
    'RMV - Kiribathgoda',
    'RMV - Kandy',
    'Passport Office - Battaramulla',
    'Passport Office - Kandy',
    'Department of Registration - Colombo',
    'NIC Service Center - Colombo',
    'NIC Service Center - Kandy',
    'Immigration Department - Battaramulla',
    'Land Registry Office - Colombo',
    'Land Registry Office - Kandy',
    'Municipal Council - Colombo',
    'Municipal Council - Kandy',
    'Registrar General Department - Colombo',
  ];

  final Map<String, double> serviceFees = {
    'Passport Renewal': 5000,
    'New Passport Application': 8000,
    'National ID Card': 500,
    'NIC Replacement': 1000,
    'Driving License': 3000,
    'License Renewal': 1500,
    'Birth Certificate': 200,
    'Marriage Certificate': 300,
    'Death Certificate': 200,
    'Police Clearance': 1000,
    'Visa Services': 4000,
    'Land Registration': 5000,
  };

  @override
  void initState() {
    super.initState();
    _updateFee();

    if (widget.preSelectedOffice != null &&
        offices.contains(widget.preSelectedOffice)) {
      selectedOffice = widget.preSelectedOffice!;
    }

    if (widget.rescheduleAppointment != null) {
      final appointment = widget.rescheduleAppointment!;
      _isReschedule = true;
      selectedService = appointment.service;
      selectedOffice = appointment.office;
      selectedDate = appointment.date;
      _selectedFee = appointment.feeAmount;

      final timeParts = appointment.time.split(' ');
      final hourMin = timeParts[0].split(':');
      int hour = int.parse(hourMin[0]);
      final minute = int.parse(hourMin[1]);
      if (timeParts[1] == 'PM' && hour != 12) hour += 12;
      if (timeParts[1] == 'AM' && hour == 12) hour = 0;
      selectedTime = TimeOfDay(hour: hour, minute: minute);
      selectedPaymentMethod = appointment.paymentMethod.isNotEmpty ? appointment.paymentMethod : 'Pay at Counter';
      _updateFee();
    }
    _checkOfficeAvailability();
  }

  void _updateFee() {
    setState(() {
      _selectedFee = serviceFees[selectedService] ?? 0;
    });
  }

  String _generateQRData() {
    final appointmentId = 'APT${DateTime.now().millisecondsSinceEpoch}';
    final tokenNumber =
        '${selectedService.substring(0, 1)}-${DateTime.now().millisecond % 1000}';

    final qrData = {
      'appointmentId': appointmentId,
      'service': selectedService,
      'office': selectedOffice,
      'date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'time': selectedTime.format(context),
      'token': tokenNumber,
      'fee': _selectedFee,
      'paymentMethod': selectedPaymentMethod,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(qrData);
  }

  // ==================== DOCUMENT UPLOAD METHODS ====================

  Future<void> _pickFile(String docId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.first.path!);
      final fileName = result.files.first.name;

      setState(() {
        _selectedFiles[docId] = file;
        _selectedFileNames[docId] = fileName;
        _isFileUploading[docId] = false;
        // Auto-select the checkbox when file is uploaded
        final index = _requiredDocs.indexWhere((d) => d.id == docId);
        if (index != -1) {
          _requiredDocs[index].selected = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('file_uploaded_successfully'.tr(args: [fileName])),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeFile(String docId) {
    setState(() {
      _selectedFiles.remove(docId);
      _selectedFileNames.remove(docId);
      final index = _requiredDocs.indexWhere((d) => d.id == docId);
      if (index != -1) {
        _requiredDocs[index].selected = false;
      }
    });
  }

  // ==================== DATE & TIME ====================

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _checkOfficeAvailability();
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
      _checkOfficeAvailability();
    }
  }

  // ==================== CONFIRMATION ====================

  void _showConfirmationDialog(String tokenNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 10),
            Text('appointment_confirmed'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text(_kBookServiceKeys[selectedService]!.tr(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(_kBookOfficeKeys[selectedOffice]!.tr(),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(selectedDate)} at ${selectedTime.format(context)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'token_label'.tr(args: [tokenNumber]),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const Divider(color: Colors.white70, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('total_fee_label'.tr(),
                          style: const TextStyle(color: Colors.white70)),
                      Text(
                        'rupee_amount'.tr(args: [_selectedFee.toStringAsFixed(0)]),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('payment_method_colon'.tr(),
                          style: const TextStyle(color: Colors.white70)),
                      Text(
                        _kPayMethodKeys[selectedPaymentMethod]!.tr(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'pay_at_counter_note'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedFiles.isNotEmpty)
                    Text(
                      'documents_uploaded_count'.tr(args: ['${_selectedFiles.length}']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text('qr_code_generated_note'.tr()),
            const SizedBox(height: 8),
            Text('show_qr_checkin_payment'.tr()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  // ==================== SUBMIT BOOKING ====================

  Future<void> _bookAppointment() async {
    setState(() => _isBooking = true);

    // Simulate upload delay
    await Future.delayed(const Duration(seconds: 1));

    final appointmentId = 'APT${DateTime.now().millisecondsSinceEpoch}';
    final tokenNumber =
        '${selectedService.substring(0, 1)}-${DateTime.now().millisecond % 1000}';
    final qrData = _generateQRData();

    // Create document attachments from selected files
    List<DocumentAttachment> attachments = [];
    for (var entry in _selectedFiles.entries) {
      final docId = entry.key;
      final file = entry.value;
      final fileName = _selectedFileNames[docId] ?? 'document.pdf';
      final doc = _requiredDocs.firstWhere((d) => d.id == docId);
      
      attachments.add(DocumentAttachment(
        id: docId,
        fileName: fileName,
        filePath: file.path,
        documentType: doc.name,
        isRequired: doc.required,
        uploadedAt: DateTime.now(),
      ));
    }

    final newAppointment = AppointmentModel(
      id: appointmentId,
      service: selectedService,
      office: selectedOffice,
      date: selectedDate,
      time: selectedTime.format(context),
      token: tokenNumber,
      status: 'Confirmed',
      qrData: qrData,
      paymentStatus: selectedPaymentMethod == 'Pay Online' ? 'paid' : 'pending',
      feeAmount: _selectedFee,
      paymentMethod: selectedPaymentMethod,
      notes: _notesController.text,
      documents: attachments,
    );

    // Save appointment with documents
    await AppointmentService.addAppointment(newAppointment);

    setState(() => _isBooking = false);

    if (mounted) {
      if (selectedPaymentMethod == 'Pay Online') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              amount: _selectedFee,
              appointmentId: appointmentId,
              serviceName: selectedService,
              officeName: selectedOffice,
            ),
          ),
        );
      } else {
        _showConfirmationDialog(tokenNumber);
      }
    }
  }

  // ==================== OFFICE AVAILABILITY ====================

  Future<void> _checkOfficeAvailability() async {
    setState(() => _availabilityLoading = true);
    final availability = await OfficeSettingsService.getOfficeAvailability(
        selectedOffice, selectedDate);
    final isWorking = await OfficeSettingsService.isOfficeWorking(
        selectedOffice, selectedDate, selectedTime);
    if (mounted) {
      setState(() {
        _officeAvailability = availability;
        _isTimeValid = isWorking;
        _availabilityLoading = false;
      });
    }
  }

  Widget _buildOfficeStatusBanner() {
    if (_availabilityLoading || _officeAvailability == null) {
      return const SizedBox.shrink();
    }

    final isOpen = _officeAvailability!['isWorking'] as bool;
    final start = _officeAvailability!['start'] as TimeOfDay?;
    final end = _officeAvailability!['end'] as TimeOfDay?;
    final lunchBreaks = _officeAvailability!['lunchBreak'] as List;

    String hoursText = '';
    if (start != null && end != null) {
      hoursText =
          '${start.format(context)} – ${end.format(context)}';
      if (lunchBreaks.isNotEmpty) {
        hoursText += '  •  ${'lunch_break_note'.tr(args: [lunchBreaks.join(', ')])}';
      }
    }

    if (!isOpen) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined,
                color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (_officeAvailability!['messageKey'] as String).tr(),
                style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isTimeValid) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'outside_working_hours'.tr(),
                    style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            if (hoursText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  'working_hours_label'.tr(args: [hoursText]),
                  style: const TextStyle(
                      color: AppColors.warning, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                'office_is_open'.tr(),
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (hoursText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                'working_hours_label'.tr(args: [hoursText]),
                style: const TextStyle(
                    color: AppColors.success, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== BUILD UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isReschedule ? 'reschedule_appointment_title'.tr() : 'book_appointment'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Selection
            Text('select_service'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(15),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedService,
                  isExpanded: true,
                  items: services.map((service) {
                    return DropdownMenuItem(
                        value: service, child: Text(_kBookServiceKeys[service]!.tr()));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedService = value!;
                      _updateFee();
                      // Reset selected files when service changes
                      _selectedFiles.clear();
                      _selectedFileNames.clear();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Office Selection
            Text('select_office'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(15),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedOffice,
                  isExpanded: true,
                  items: offices.map((office) {
                    return DropdownMenuItem(value: office, child: Text(_kBookOfficeKeys[office]!.tr()));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedOffice = value!);
                    _checkOfficeAvailability();
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date Selection
            Text('select_date'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppColors.primaryBlue),
                    const SizedBox(width: 15),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(selectedDate),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Time Selection
            Text('select_time'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: AppColors.primaryBlue),
                    const SizedBox(width: 15),
                    Text(
                      selectedTime.format(context),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            _buildOfficeStatusBanner(),
            const SizedBox(height: 20),

            // ==================== OPTIONAL DOCUMENTS SECTION ====================
            Text(
              'upload_documents_optional'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'upload_supporting_docs_count'.tr(args: ['${_selectedFiles.length}']),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),

            // Document upload tiles (all optional)
            ..._requiredDocs.map((doc) => _buildDocumentTile(doc)).toList(),

            const SizedBox(height: 20),

            // Payment Method
            Text('payment_method'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                        () => selectedPaymentMethod = 'Pay at Counter'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedPaymentMethod == 'Pay at Counter'
                            ? AppColors.primaryBlue
                            : AppColors.offWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedPaymentMethod == 'Pay at Counter'
                              ? AppColors.primaryBlue
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments,
                            color: selectedPaymentMethod == 'Pay at Counter'
                                ? Colors.white
                                : AppColors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'pay_at_counter'.tr(),
                            style: TextStyle(
                              color: selectedPaymentMethod == 'Pay at Counter'
                                  ? Colors.white
                                  : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => selectedPaymentMethod = 'Pay Online'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedPaymentMethod == 'Pay Online'
                            ? AppColors.primaryBlue
                            : AppColors.offWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedPaymentMethod == 'Pay Online'
                              ? AppColors.primaryBlue
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code,
                            color: selectedPaymentMethod == 'Pay Online'
                                ? Colors.white
                                : AppColors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'pay_online'.tr(),
                            style: TextStyle(
                              color: selectedPaymentMethod == 'Pay Online'
                                  ? Colors.white
                                  : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (selectedPaymentMethod == 'Pay Online')
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'redirect_payment_gateway_note'.tr(),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Fee Display Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.currency_rupee,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('service_fee_label'.tr(),
                            style:
                                const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          'rupee_amount'.tr(args: [_selectedFee.toStringAsFixed(0)]),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      selectedPaymentMethod == 'Pay Online'
                          ? 'online_label'.tr()
                          : 'counter_label'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Additional Notes
            Text('additional_notes_optional'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'special_requirements_hint'.tr(),
                filled: true,
                fillColor: AppColors.offWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_isBooking || !_canBook) ? null : _bookAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: _isBooking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isReschedule
                            ? 'confirm_reschedule'.tr()
                            : 'confirm_appointment'.tr(),
                        style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DOCUMENT TILE WIDGET ====================

  Widget _buildDocumentTile(DocumentRequirement doc) {
    final isFileSelected = _selectedFiles.containsKey(doc.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFileSelected ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFileSelected ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Checkbox(
            value: doc.selected,
            onChanged: (value) {
              setState(() {
                doc.selected = value ?? false;
                if (!doc.selected && _selectedFiles.containsKey(doc.id)) {
                  _selectedFiles.remove(doc.id);
                  _selectedFileNames.remove(doc.id);
                }
              });
            },
            activeColor: AppColors.primaryBlue,
          ),
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFileSelected ? Colors.green.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              doc.icon,
              size: 20,
              color: isFileSelected ? Colors.green : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 10),
          // Document info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        doc.nameKey.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'optional_label'.tr(),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  doc.descKey.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                // File name if selected
                if (isFileSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 12,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _selectedFileNames[doc.id] ?? 'file_uploaded_default'.tr(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeFile(doc.id),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Upload button
          isFileSelected
              ? IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => _pickFile(doc.id),
                  color: AppColors.primaryBlue,
                  tooltip: 'change_file_tooltip'.tr(),
                )
              : ElevatedButton(
                  onPressed: () => _pickFile(doc.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('upload_label'.tr()),
                ),
        ],
      ),
    );
  }
}

// ==================== DOCUMENT REQUIREMENT MODEL ====================

class DocumentRequirement {
  final String id;
  final String name;
  final String nameKey;
  final String description;
  final String descKey;
  final IconData icon;
  final bool required;
  bool selected;

  DocumentRequirement({
    required this.id,
    required this.name,
    required this.nameKey,
    required this.description,
    required this.descKey,
    required this.icon,
    required this.required,
    this.selected = false,
  });
}