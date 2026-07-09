import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, String> _kServiceNameKeys = {
  'Passport Renewal': 'svc_passport_renewal_name',
  'National ID Card': 'svc_national_id_name',
  'Driving License': 'svc_driving_license_name',
  'Birth Certificate': 'svc_birth_certificate_name',
  'Police Clearance': 'svc_police_clearance_name',
  'Visa Services': 'svc_visa_services_name',
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
    'National ID Card',
    'Driving License',
    'Birth Certificate',
    'Police Clearance',
    'Visa Services',
  ];

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