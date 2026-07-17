import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/config/backend_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, String> _kServiceNameKeys = {
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

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  double rating = 0;
  String selectedService = 'Passport Renewal';
  final TextEditingController commentController = TextEditingController();
  bool isSubmitting = false;

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

  Future<void> _mirrorFeedbackToBackend({
    required String citizenName,
    required String citizenNic,
    required String service,
    required int rating,
    required String comment,
  }) async {
    try {
      await http.post(
        Uri.parse('${BackendConfig.baseUrl}/api/web/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'citizenName': citizenName,
          'citizenNic': citizenNic.isNotEmpty ? citizenNic : null,
          'service': service,
          'rating': rating,
          'comment': comment,
        }),
      );
    } catch (e) {
      debugPrint('Feedback backend mirror failed: $e');
    }
  }

  /// Notifies staff the moment a citizen submits feedback, via the same
  /// `staff_notifications` collection the officer dashboard's bell icon
  /// already listens to live (see `AppointmentService._notifyStaffOfNewAppointment`
  /// for the identical pattern). All 5 officer roles can review/reply to
  /// feedback from their Dashboard, so all 5 are targeted.
  Future<void> _notifyStaffOfFeedback({
    required String citizenName,
    required String service,
    required int rating,
    required String comment,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('staff_notifications').add({
        'title': 'New Feedback Received',
        'message': comment.isNotEmpty
            ? '$citizenName rated $service $rating/5: "$comment"'
            : '$citizenName rated $service $rating/5.',
        'type': 'feedback',
        'action': 'View Feedback',
        'targetRoles': const ['admin', 'queueManager', 'serviceProcessor', 'reception', 'departmentManager'],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'service': service,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyStaffOfFeedback failed: $e');
    }
  }

  Future<void> _submitFeedback() async {
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_rate_experience'.tr()), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    
    setState(() => isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'Citizen';
    
    // Save feedback (in real app, send to backend)
    final feedback = {
      'user': userName,
      'service': selectedService,
      'rating': rating,
      'comment': commentController.text,
      'date': DateTime.now().toIso8601String(),
    };
    
    // Store in local storage
    final existingFeedback = prefs.getStringList('user_feedback') ?? [];
    existingFeedback.add(feedback.toString());
    await prefs.setStringList('user_feedback', existingFeedback);

    // Mirror to the backend so it counts toward the officer dashboard's
    // Avg. Satisfaction stat. Fire-and-forget — never blocks the citizen.
    final nic = prefs.getString('userNIC') ?? '';
    _mirrorFeedbackToBackend(
      citizenName: userName,
      citizenNic: nic,
      service: selectedService,
      rating: rating.toInt(),
      comment: commentController.text,
    );

    // Fire-and-forget — never blocks the citizen.
    _notifyStaffOfFeedback(
      citizenName: userName,
      service: selectedService,
      rating: rating.toInt(),
      comment: commentController.text,
    );

    setState(() => isSubmitting = false);
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('thank_you_exclaim'.tr()),
          content: Text('feedback_helps_improve'.tr()),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('feedback_action'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text('how_was_experience'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => rating = index + 1.0),
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                      size: 45,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                rating > 0 ? 'you_rated_stars'.tr(args: ['$rating']) : 'tap_to_rate'.tr(),
                style: TextStyle(fontSize: 14, color: AppColors.grey),
              ),
            ),
            const SizedBox(height: 30),
            Text('select_service'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    return DropdownMenuItem(value: service, child: Text(_kServiceNameKeys[service]!.tr()));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedService = value!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('your_feedback'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'share_experience_hint'.tr(),
                filled: true,
                fillColor: AppColors.offWhite,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('submit_feedback'.tr(), style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}