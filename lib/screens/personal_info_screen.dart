import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:queuenova_mobile/screens/edit_profile_picture_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  String fullName = '';
  String email = '';
  String phone = '';
  String address = '';
  String nic = '';
  String birthDate = '';
  String gender = '';
  String memberSince = '';
  bool isEditing = false;
  bool isLoading = true;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);

    setState(() {
      final rawName = authService.userName ?? prefs.getString('userName');
      fullName = (rawName != null && rawName.isNotEmpty && rawName != 'Citizen User') ? rawName : '';
      nic = authService.userNIC ?? prefs.getString('userNIC') ?? '';
      birthDate = authService.userBirthDate ?? prefs.getString('userBirthDate') ?? '';
      gender = authService.userGender ?? prefs.getString('userGender') ?? '';
      final rawEmail = authService.userEmail ?? prefs.getString('userEmail');
      email = (rawEmail != null && rawEmail.isNotEmpty && rawEmail != 'citizen@example.com') ? rawEmail : '';
      final rawPhone = authService.userPhone ?? prefs.getString('userPhone');
      phone = rawPhone ?? '';
      address = prefs.getString('userAddress') ?? '';
      final memberSinceMonth = prefs.getInt('memberSinceMonth');
      final memberSinceYear = prefs.getInt('memberSinceYear');
      memberSince = (memberSinceMonth != null && memberSinceYear != null)
          ? DateFormat('MMMM yyyy', context.locale.toString()).format(DateTime(memberSinceYear, memberSinceMonth))
          : '';
      isLoading = false;

      nameController.text = fullName;
      emailController.text = email;
      phoneController.text = phone;
      addressController.text = address;
    });
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Widget _buildPhotoWidget(String? photoData, String? name, double size) {
    final initials = Center(
      child: Text(
        _getInitials(name),
        style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold),
      ),
    );
    if (photoData == null) return initials;
    try {
      final bytes = base64Decode(photoData);
      return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => initials);
    } catch (_) {
      return Image.network(photoData, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => initials);
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        fullName = nameController.text;
        email = emailController.text;
        phone = phoneController.text;
        address = addressController.text;
        isEditing = false;
      });

      // Update Firestore + SharedPreferences + notify all listeners so the
      // home screen name refreshes immediately without an app restart.
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.updateUserProfile(
        name: fullName,
        email: email,
        phone: phone,
        address: address,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('personal_info_updated'.tr()),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('personal_information'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => setState(() => isEditing = true),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const EditProfilePictureScreen()),
                      ),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: ClipOval(
                          child: _buildPhotoWidget(
                              authService.userPhotoUrl,
                              authService.userName,
                              100),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const EditProfilePictureScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // NIC Number (Auto-filled from registration, cannot edit)
              _buildReadOnlyField('nic_number'.tr(),
                  nic.isNotEmpty ? nic : 'not_provided'.tr(), Icons.badge_outlined),
              const SizedBox(height: 16),

              // Date of Birth (Auto-extracted from NIC during registration)
              _buildReadOnlyField('date_of_birth'.tr(),
                  birthDate.isNotEmpty ? birthDate : 'not_available'.tr(), Icons.cake_outlined),
              const SizedBox(height: 16),

              // Gender (Auto-extracted from NIC during registration)
              _buildReadOnlyField('gender'.tr(), _genderLabel(gender), Icons.wc_outlined),
              const SizedBox(height: 16),

              // Full Name (Editable)
              if (isEditing)
                _buildEditableField(
                    'full_name'.tr(), nameController, Icons.person_outline)
              else
                _buildReadOnlyField(
                    'full_name'.tr(), fullName, Icons.person_outline),
              const SizedBox(height: 16),

              // Email (Editable)
              if (isEditing)
                _buildEditableField(
                    'email_address'.tr(), emailController, Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress)
              else
                _buildReadOnlyField(
                    'email_address'.tr(), email, Icons.email_outlined),
              const SizedBox(height: 16),

              // Phone (Editable)
              if (isEditing)
                _buildEditableField(
                    'phone_number'.tr(), phoneController, Icons.phone_outlined,
                    keyboardType: TextInputType.phone)
              else
                _buildReadOnlyField(
                    'phone_number'.tr(), phone, Icons.phone_outlined),
              const SizedBox(height: 16),

              // Address (Editable)
              if (isEditing)
                _buildEditableField(
                    'address'.tr(), addressController, Icons.location_on_outlined,
                    maxLines: 2)
              else
                _buildReadOnlyField(
                    'address'.tr(), address, Icons.location_on_outlined),
              const SizedBox(height: 16),

              // Member Since
              _buildReadOnlyField('member_since_label'.tr(),
                  memberSince.isNotEmpty ? memberSince : 'not_available'.tr(), Icons.calendar_today_outlined),
              const SizedBox(height: 24),

              if (isEditing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            isEditing = false;
                            nameController.text = fullName;
                            emailController.text = email;
                            phoneController.text = phone;
                            addressController.text = address;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: Text('cancel'.tr(),
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: Text('save'.tr()),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _genderLabel(String g) {
    switch (g) {
      case 'Male':
        return 'gender_male'.tr();
      case 'Female':
        return 'gender_female'.tr();
      default:
        return 'not_available'.tr();
    }
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.offWhite, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: AppColors.primaryBlue)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
      String label, TextEditingController controller, IconData icon,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.offWhite, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: AppColors.primaryBlue)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero),
                  validator: (value) => value == null || value.isEmpty
                      ? 'field_is_required'.tr(args: [label])
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
