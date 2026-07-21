import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/models/appointment_model.dart' show DocumentAttachment;
import 'package:queuenova_mobile/services/online_service_request_service.dart';
import 'package:queuenova_mobile/services/services_catalog_service.dart';
import 'package:queuenova_mobile/screens/payment_screen.dart';

/// Supporting documents commonly needed per service — a smaller, self
/// contained version of the requirement lists BookAppointmentScreen uses,
/// since an online request always needs *some* proof (there's no in-person
/// officer to verify originals against). Falls back to a generic NIC-based
/// list for any service not covered here.
const Map<String, List<_DocSpec>> _kDocRequirements = {
  'Marriage Certificate': [
    _DocSpec('NIC of Both Parties', Icons.people_outline),
    _DocSpec('Birth Certificates', Icons.celebration_outlined),
  ],
  'Birth Certificate': [
    _DocSpec('Parents NIC', Icons.people_outline),
    _DocSpec('Hospital Birth Record', Icons.local_hospital_outlined),
  ],
  'Death Certificate': [
    _DocSpec('Medical Certificate', Icons.health_and_safety_outlined),
    _DocSpec('Deceased NIC', Icons.badge_outlined),
  ],
  'Police Clearance': [
    _DocSpec('National ID Card', Icons.badge_outlined),
    _DocSpec('Passport Size Photo', Icons.photo_camera_outlined),
  ],
  'National ID Card': [
    _DocSpec('Birth Certificate', Icons.celebration_outlined),
    _DocSpec('Proof of Address', Icons.home_outlined),
  ],
  'NIC Replacement': [
    _DocSpec('Police Report', Icons.report_outlined),
    _DocSpec('Proof of Address', Icons.home_outlined),
  ],
};

const List<_DocSpec> _kDefaultDocs = [
  _DocSpec('National ID Card', Icons.badge_outlined),
  _DocSpec('Supporting Document', Icons.description_outlined),
];

class _DocSpec {
  final String name;
  final IconData icon;
  const _DocSpec(this.name, this.icon);
}

class OnlineServiceRequestScreen extends StatefulWidget {
  final String? preSelectedService;

  const OnlineServiceRequestScreen({super.key, this.preSelectedService});

  @override
  State<OnlineServiceRequestScreen> createState() => _OnlineServiceRequestScreenState();
}

class _OnlineServiceRequestScreenState extends State<OnlineServiceRequestScreen> {
  List<Map<String, dynamic>> _services = [];
  String? _selectedService;
  bool _loadingServices = true;
  bool _submitting = false;

  final TextEditingController _reasonController = TextEditingController();
  final Map<String, PlatformFile> _selectedFiles = {};

  Map<String, dynamic>? get _selectedServiceData =>
      _services.firstWhere((s) => s['name'] == _selectedService, orElse: () => const {});

  bool get _onlineEligible => _selectedServiceData?['online_eligible'] != false;
  double get _fee => double.tryParse(_selectedServiceData?['fee']?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    final services = await ServicesCatalogService.getServices();
    if (!mounted) return;
    setState(() {
      _services = services;
      _loadingServices = false;
      if (services.isNotEmpty) {
        _selectedService = widget.preSelectedService != null &&
                services.any((s) => s['name'] == widget.preSelectedService)
            ? widget.preSelectedService
            : services.first['name'] as String;
      }
    });
  }

  List<_DocSpec> get _requiredDocs => _kDocRequirements[_selectedService] ?? _kDefaultDocs;

  Future<void> _pickFile(String docName) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final hasPath = !kIsWeb && picked.path != null;
      if (picked.bytes == null && !hasPath) {
        throw Exception('No file data returned by picker');
      }
      setState(() => _selectedFiles[docName] = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File upload failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _removeFile(String docName) => setState(() => _selectedFiles.remove(docName));

  bool get _canSubmit {
    if (_submitting || _selectedService == null) return false;
    if (!_onlineEligible && _reasonController.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_onlineEligible && _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This service normally requires an in-person visit. Please state your reason (e.g. a court ruling) to request an exception.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final requestId = 'OSR${DateTime.now().millisecondsSinceEpoch}';
      final documents = _selectedFiles.entries.map((entry) {
        final file = entry.value;
        return DocumentAttachment(
          id: entry.key,
          fileName: file.name,
          filePath: (!kIsWeb && file.path != null) ? file.path! : file.name,
          documentType: entry.key,
          isRequired: false,
          uploadedAt: DateTime.now(),
          bytes: file.bytes,
        );
      }).toList();

      final fee = await OnlineServiceRequestService.submitRequest(
        id: requestId,
        service: _selectedService!,
        isExceptionRequest: !_onlineEligible,
        exceptionReason: !_onlineEligible ? _reasonController.text.trim() : null,
        documents: documents,
      );

      if (!mounted) return;

      if (fee > 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              amount: fee,
              appointmentId: requestId,
              requestType: 'online_request',
              serviceName: _selectedService!,
              officeName: 'Online Service Request',
            ),
          ),
        );
      } else {
        _showSubmittedDialog();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSubmittedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 10),
            const Text('Request Submitted'),
          ],
        ),
        content: const Text(
          'Your online service request has been submitted and is awaiting review by a Service Officer. '
          'You can track its progress from the Track Requests screen.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Service Request'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loadingServices
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: AppColors.primaryBlue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Request this service fully online — no need to visit the office in person. Upload your documents, pay online, and track progress here.',
                            style: TextStyle(fontSize: 12, color: AppColors.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Select Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: AppColors.offWhite,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedService,
                        isExpanded: true,
                        items: _services
                            .map((s) => DropdownMenuItem(
                                  value: s['name'] as String,
                                  child: Text(s['name'] as String),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() {
                          _selectedService = value;
                          _selectedFiles.clear();
                          _reasonController.clear();
                        }),
                      ),
                    ),
                  ),
                  if (!_onlineEligible) ...[
                    const SizedBox(height: 16),
                    Container(
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
                              const Icon(Icons.gavel_outlined, size: 18, color: AppColors.warning),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'This service normally requires a physical appointment. You may still request it online if you have a specific reason (e.g. a court ruling).',
                                  style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'State your reason for requesting this online (required)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Upload Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${_selectedFiles.length} of ${_requiredDocs.length} uploaded',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  ..._requiredDocs.map((doc) => _buildDocumentTile(doc)),
                  const SizedBox(height: 20),
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
                          child: const Icon(Icons.currency_rupee, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Service Fee', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(
                                _fee > 0 ? 'Rs. ${_fee.toStringAsFixed(0)}' : 'Free',
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        if (_fee > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Pay Online', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_fee > 0 ? 'Continue to Payment' : 'Submit Request', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDocumentTile(_DocSpec doc) {
    final isFileSelected = _selectedFiles.containsKey(doc.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFileSelected ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFileSelected ? Colors.green.shade300 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFileSelected ? Colors.green.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(doc.icon, size: 20, color: isFileSelected ? Colors.green : Colors.grey.shade600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (isFileSelected)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _selectedFiles[doc.name]!.name,
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeFile(doc.name),
                          child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          isFileSelected
              ? IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => _pickFile(doc.name),
                  color: AppColors.primaryBlue,
                )
              : ElevatedButton(
                  onPressed: () => _pickFile(doc.name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Upload'),
                ),
        ],
      ),
    );
  }
}
