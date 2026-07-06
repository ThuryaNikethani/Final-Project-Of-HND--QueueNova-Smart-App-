import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:queuenova_mobile/screens/login_screen.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // NIC decoded info
  String _decodedBirthDate = '';
  String _decodedGender = '';
  bool _isValidNIC = false;

  // Function to decode NIC and extract info
  void _decodeNIC(String nic) {
    final upperNIC = nic.toUpperCase();
    
    if (upperNIC.length == 10 && RegExp(r'^[0-9]{9}[VX]$').hasMatch(upperNIC)) {
      int birthYear = 1900 + int.parse(upperNIC.substring(0, 2));
      int dayOfYear = int.parse(upperNIC.substring(2, 5));
      String gender;
      
      if (dayOfYear > 500) {
        gender = 'Female';
        dayOfYear = dayOfYear - 500;
      } else {
        gender = 'Male';
      }
      
      final date = DateTime(birthYear, 1, 1).add(Duration(days: dayOfYear - 1));
      setState(() {
        _decodedBirthDate = '${date.day} ${_getMonthName(date.month)} ${date.year}';
        _decodedGender = gender;
        _isValidNIC = true;
      });
    } 
    else if (upperNIC.length == 12 && RegExp(r'^[0-9]{12}$').hasMatch(upperNIC)) {
      int birthYear = int.parse(upperNIC.substring(0, 4));
      int dayOfYear = int.parse(upperNIC.substring(4, 7));
      String gender;
      
      if (dayOfYear > 500) {
        gender = 'Female';
        dayOfYear = dayOfYear - 500;
      } else {
        gender = 'Male';
      }
      
      final date = DateTime(birthYear, 1, 1).add(Duration(days: dayOfYear - 1));
      setState(() {
        _decodedBirthDate = '${date.day} ${_getMonthName(date.month)} ${date.year}';
        _decodedGender = gender;
        _isValidNIC = true;
      });
    }
    else {
      setState(() {
        _decodedBirthDate = '';
        _decodedGender = '';
        _isValidNIC = false;
      });
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('passwords_do_not_match'.tr()), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!_isValidNIC) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enter_valid_nic'.tr()), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.register(
      name: _nameController.text.trim(),
      nic: _nicController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('registration_successful'.tr()), backgroundColor: AppColors.success),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else if (mounted) {
      final errorKey = switch (authService.lastRegisterError) {
        'duplicate_nic' => 'nic_already_registered',
        'duplicate_email' => 'email_already_registered',
        _ => 'registration_failed',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorKey.tr()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('create_account'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Icon
              Center(
                child: Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: const Center(child: Icon(Icons.person_add_alt_rounded, size: 35, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              Text('join_queuenova'.tr(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('create_account_subtitle'.tr(), style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              
              // Full Name
              _buildTextField(controller: _nameController, label: 'full_name'.tr(), hint: 'enter_full_name_hint'.tr(), icon: Icons.person_outline),
              const SizedBox(height: 16),
              
              // NIC Number (with auto-decode)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _nicController,
                    label: 'nic_number'.tr(),
                    hint: 'e.g., 855420159V or 19855420159',
                    icon: Icons.badge_outlined,
                    onChanged: (value) => _decodeNIC(value),
                  ),
                  if (_nicController.text.isNotEmpty && _isValidNIC)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Text('valid_nic_number'.tr(), style: TextStyle(color: AppColors.success, fontSize: 12)),
                        ],
                      ),
                    ),
                  if (_nicController.text.isNotEmpty && !_isValidNIC && _nicController.text.length > 5)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Text('invalid_nic_number'.tr(), style: TextStyle(color: AppColors.error, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // NIC Decoded Info (Birth Date & Gender)
              if (_isValidNIC && _nicController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cake, color: AppColors.primaryBlue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text('date_of_birth'.tr(), style: TextStyle(color: AppColors.grey))),
                          Text(_decodedBirthDate, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.wc, color: AppColors.primaryBlue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text('gender'.tr(), style: TextStyle(color: AppColors.grey))),
                          Text(_decodedGender, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              
              // Email
              _buildTextField(controller: _emailController, label: 'email_address'.tr(), hint: 'enter_email_hint'.tr(), icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              
              // Phone
              _buildTextField(controller: _phoneController, label: 'phone_number'.tr(), hint: 'enter_phone_hint'.tr(), icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              
              // Password
              _buildTextField(
                controller: _passwordController,
                label: 'password'.tr(),
                hint: 'create_password_hint'.tr(),
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.grey),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 16),
              
              // Confirm Password
              _buildTextField(
                controller: _confirmPasswordController,
                label: 'confirm_password'.tr(),
                hint: 'confirm_password_hint'.tr(),
                icon: Icons.lock_outline,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.grey),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              const SizedBox(height: 32),
              
              // Register Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('sign_up'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              
              // Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('already_have_account'.tr(), style: TextStyle(color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('sign_in'.tr(), style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: (value) => value!.isEmpty ? 'field_is_required'.tr(args: [label]) : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.grey),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          ),
        ),
      ],
    );
  }
}