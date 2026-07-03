import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/models/appointment_model.dart';
import 'package:queuenova_mobile/services/appointment_service.dart';
import 'package:queuenova_mobile/services/office_settings_service.dart';
import 'package:queuenova_mobile/screens/payment_screen.dart';

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
            description: 'Previous passport (if available)',
            icon: Icons.airplane_ticket_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            description: 'Recent passport size photo (white background)',
            icon: Icons.photo_camera_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            description: 'Copy of your NIC',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'proof_of_address',
            name: 'Proof of Address',
            description: 'Utility bill or bank statement',
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
            description: 'Copy of birth certificate',
            icon: Icons.celebration_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'proof_of_address',
            name: 'Proof of Address',
            description: 'Utility bill or bank statement',
            icon: Icons.home_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'police_report',
            name: 'Police Report',
            description: 'For lost NIC replacement',
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
            description: 'Medical fitness certificate',
            icon: Icons.health_and_safety_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            description: 'Copy of your NIC',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            description: 'Recent passport size photo',
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
            description: 'Previous driving license',
            icon: Icons.directions_car_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            description: 'Copy of your NIC',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            description: 'Recent passport size photo',
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
            description: 'NIC of both parents',
            icon: Icons.people_outline,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'hospital_record',
            name: 'Hospital Birth Record',
            description: 'Birth record from hospital',
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
            description: 'NIC of bride and groom',
            icon: Icons.people_outline,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'birth_certificates',
            name: 'Birth Certificates',
            description: 'Birth certificates of both parties',
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
            description: 'Medical certificate of death',
            icon: Icons.health_and_safety_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'deceased_nic',
            name: 'Deceased NIC',
            description: 'NIC of the deceased',
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
            description: 'Copy of your NIC',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            description: 'Recent passport size photo',
            icon: Icons.photo_camera_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'proof_of_address',
            name: 'Proof of Address',
            description: 'Utility bill or bank statement',
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
            description: 'Current passport copy',
            icon: Icons.airplane_ticket_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'passport_photo',
            name: 'Passport Size Photo',
            description: 'Recent passport size photo',
            icon: Icons.photo_camera_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'proof_of_address',
            name: 'Proof of Address',
            description: 'Utility bill or bank statement',
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
            description: 'Original land deed',
            icon: Icons.description_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'nic',
            name: 'National ID Card',
            description: 'Copy of your NIC',
            icon: Icons.badge_outlined,
            required: false,
            selected: false,
          ),
          DocumentRequirement(
            id: 'survey_plan',
            name: 'Survey Plan',
            description: 'Land survey plan',
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
            description: 'Copy of your NIC',
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
          content: Text('$fileName uploaded successfully'),
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
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 10),
            Text('Appointment Confirmed'),
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
                  Text(selectedService,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(selectedOffice,
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
                    'Token: $tokenNumber',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const Divider(color: Colors.white70, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Fee:',
                          style: TextStyle(color: Colors.white70)),
                      Text(
                        'Rs. ${_selectedFee.toStringAsFixed(0)}',
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
                      const Text('Payment Method:',
                          style: TextStyle(color: Colors.white70)),
                      Text(
                        selectedPaymentMethod,
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
                    child: const Text(
                      'Pay at counter when you visit',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedFiles.isNotEmpty)
                    Text(
                      'Documents uploaded: ${_selectedFiles.length} file(s)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text('QR code has been generated for this appointment.'),
            const SizedBox(height: 8),
            const Text(
                'Show QR code at the service center for check-in and payment.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
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
        hoursText += '  •  Lunch: ${lunchBreaks.join(', ')}';
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
                _officeAvailability!['message'] as String,
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
                const Expanded(
                  child: Text(
                    'Selected time is outside working hours',
                    style: TextStyle(
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
                  'Working hours: $hoursText',
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
          const Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text(
                'Office is open',
                style: TextStyle(
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
                'Working hours: $hoursText',
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
            Text(_isReschedule ? 'Reschedule Appointment' : 'Book Appointment'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Selection
            const Text('Select Service',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        value: service, child: Text(service));
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
            const Text('Select Office',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    return DropdownMenuItem(value: office, child: Text(office));
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
            const Text('Select Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            const Text('Select Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            const Text(
              'Upload Documents (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You can upload supporting documents if available (${_selectedFiles.length} uploaded)',
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
            const Text('Payment Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            'Pay at Counter',
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
                            'Pay Online',
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
                        'You will be redirected to payment gateway after booking',
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
                        const Text('Service Fee',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          'Rs. ${_selectedFee.toStringAsFixed(0)}',
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
                          ? 'Online'
                          : 'Counter',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Additional Notes
            const Text('Additional Notes (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any special requirements or notes...',
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
                            ? 'Confirm Reschedule'
                            : 'Confirm Appointment',
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
                  children: [
                    Text(
                      doc.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
                        'Optional',
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
                  doc.description,
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
                            _selectedFileNames[doc.id] ?? 'File uploaded',
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
                  tooltip: 'Change file',
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
                  child: const Text('Upload'),
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
  final String description;
  final IconData icon;
  final bool required;
  bool selected;

  DocumentRequirement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.required,
    this.selected = false,
  });
}