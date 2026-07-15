import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'web_role_model.dart';
import 'web_notification_settings.dart';
import 'web_settings_screen.dart'; // Add this import for Settings screen
import 'web_api_service.dart';
import 'web_session.dart';
import 'web_login.dart';

class WebProfile extends StatefulWidget {
  final UserRole userRole;
  final String userName;
  final String userEmail;
  final String staffId;

  const WebProfile({
    super.key,
    required this.userRole,
    required this.userName,
    required this.userEmail,
    required this.staffId,
  });

  @override
  State<WebProfile> createState() => _WebProfileState();
}

class _WebProfileState extends State<WebProfile> {
  bool isEditing = false;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _photoBase64;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  /// staff_users.id — null when logged in via the hardcoded-fallback demo
  /// login path (no real backend account to persist changes against).
  int? get _numericStaffId => int.tryParse(widget.staffId);

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userName;
    _emailController.text = widget.userEmail;
    _departmentController.text = _getDepartmentByRole(widget.userRole);
    _loadPhoneFromApi();
  }

  Future<void> _loadPhoneFromApi() async {
    final id = _numericStaffId;
    if (id == null) return;
    final users = await WebApiService.getUsers();
    final match = users.firstWhere((u) => u['id'] == id, orElse: () => {});
    if (!mounted || match.isEmpty) return;
    setState(() {
      _phoneController.text = match['phone'] as String? ?? '';
      _photoBase64 = match['photo_url'] as String?;
    });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload, color: Color(0xFF1A56DB)),
              title: Text('web_upload_photo'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndUploadPhoto();
              },
            ),
            if (_photoBase64 != null && _photoBase64!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text('web_remove_photo'.tr()),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmRemovePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final encoded = base64Encode(bytes);

    final id = _numericStaffId;
    if (id == null) return;
    setState(() => _isUploadingPhoto = true);
    final success = await WebApiService.updatePhoto(id, encoded, updatedBy: widget.userName);
    if (!mounted) return;
    setState(() {
      _isUploadingPhoto = false;
      if (success) _photoBase64 = encoded;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'web_photo_updated_success'.tr() : 'web_photo_update_failed'.tr()),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _confirmRemovePhoto() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('web_remove_photo'.tr()),
        content: Text('web_remove_photo_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final id = _numericStaffId;
              if (id == null) return;
              setState(() => _isUploadingPhoto = true);
              final success = await WebApiService.updatePhoto(id, null, updatedBy: widget.userName);
              if (!mounted) return;
              setState(() {
                _isUploadingPhoto = false;
                if (success) _photoBase64 = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'web_photo_removed_success'.tr() : 'web_photo_update_failed'.tr()),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete_button'.tr()),
          ),
        ],
      ),
    );
  }

  String _getDepartmentByRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'web_dept_system_administration'.tr();
      case UserRole.queueManager:
        return 'web_dept_queue_management'.tr();
      case UserRole.serviceProcessor:
        return 'web_dept_service_processing'.tr();
      case UserRole.reception:
        return 'web_dept_reception'.tr();
      case UserRole.departmentManager:
        return 'web_dept_management'.tr();
    }
  }

  void _saveChanges() async {
    final id = _numericStaffId;
    setState(() => _isLoading = true);
    bool success = true;
    if (id != null) {
      success = await WebApiService.updateUser(
        id: id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: RolePermissions.getRoleName(widget.userRole),
        phone: _phoneController.text.trim(),
        updatedBy: widget.userName,
      );
      if (success) {
        // Keep the persisted session in sync so a page refresh doesn't
        // revert the name/email back to the pre-edit values.
        await WebSession.save(
          staffId: widget.staffId,
          userName: _nameController.text.trim(),
          userEmail: _emailController.text.trim(),
          userRole: widget.userRole,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      isEditing = false;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'web_profile_updated_success'.tr() : 'web_profile_update_failed'.tr()),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('web_passwords_do_not_match'.tr()),
            backgroundColor: Colors.red),
      );
      return;
    }

    final id = _numericStaffId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('web_password_change_failed'.tr()),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await WebApiService.changePassword(
      id,
      _currentPasswordController.text,
      _newPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.error ?? 'web_password_change_failed'.tr()),
            backgroundColor: Colors.red),
      );
      return;
    }

    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('web_password_changed_success'.tr()),
          backgroundColor: Colors.green),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('web_change_password'.tr()),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'web_current_password'.tr(),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'web_new_password'.tr(),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'web_confirm_new_password'.tr(),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB)),
              child: Text('web_update_password'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('web_profile_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A56DB)),
              onPressed: () => setState(() => isEditing = true),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _nameController.text = widget.userName;
                _emailController.text = widget.userEmail;
              });
              _loadPhoneFromApi();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: (_photoBase64 == null || _photoBase64!.isEmpty)
                                ? AppColors.primaryGradient
                                : null,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: (_photoBase64 != null && _photoBase64!.isNotEmpty)
                              ? ClipOval(
                                  child: Image.memory(
                                    base64Decode(_photoBase64!),
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    widget.userName.isNotEmpty
                                        ? widget.userName[0].toUpperCase()
                                        : 'A',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                        if (_isUploadingPhoto)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: RolePermissions.getRoleColor(widget.userRole)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        RolePermissions.getRoleName(widget.userRole),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: RolePermissions.getRoleColor(widget.userRole),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 10)
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                            'web_personal_information'.tr(), Icons.person_outline),
                        const Divider(height: 1),
                        _buildInfoRow(
                            'full_name'.tr(), _nameController.text, Icons.person,
                            isEditing: isEditing, controller: _nameController),
                        _buildInfoRow(
                            'email_address'.tr(), _emailController.text, Icons.email,
                            isEditing: isEditing, controller: _emailController),
                        _buildInfoRow(
                            'phone_number'.tr(), _phoneController.text, Icons.phone,
                            isEditing: isEditing, controller: _phoneController),
                        _buildInfoRow('web_department'.tr(),
                            _getDepartmentByRole(widget.userRole),
                            Icons.business,
                            isEditing: false, isReadOnly: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 10)
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader('web_account_information'.tr(),
                            Icons.account_circle_outlined),
                        const Divider(height: 1),
                        _buildInfoRow('web_user_id'.tr(), widget.userEmail.split('@')[0],
                            Icons.badge,
                            isEditing: false, isReadOnly: true),
                        _buildInfoRow(
                            'web_role'.tr(),
                            RolePermissions.getRoleName(widget.userRole),
                            Icons.work,
                            isEditing: false,
                            isReadOnly: true),
                        _buildInfoRow(
                            'member_since_label'.tr(), 'May 2026', Icons.calendar_today,
                            isEditing: false, isReadOnly: true),
                        _buildInfoRow(
                            'web_last_login'.tr(),
                            DateTime.now().toString().substring(0, 16),
                            Icons.history,
                            isEditing: false,
                            isReadOnly: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 10)
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                            'web_settings_preferences'.tr(), Icons.settings_outlined),
                        const Divider(height: 1),
                        // NEW: Settings Option added here
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.settings,
                                color: Colors.purple),
                          ),
                          title: Text('web_settings'.tr()),
                          subtitle: Text(
                              'web_settings_list_subtitle'.tr()),
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WebSettings(
                                  userRole: widget.userRole,
                                  userName: widget.userName,
                                  userEmail: widget.userEmail,
                                  staffId: widget.staffId,
                                ),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.lock_reset,
                                color: Colors.orange),
                          ),
                          title: Text('web_change_password'.tr()),
                          subtitle: Text('web_change_password_sub'.tr()),
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.grey),
                          onTap: _showChangePasswordDialog,
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.notifications_active,
                                color: Colors.blue),
                          ),
                          title: Text('web_notification_settings'.tr()),
                          subtitle: Text(
                              'web_notification_settings_sub'.tr()),
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WebNotificationSettings(staffId: widget.staffId),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.red),
                          ),
                          title: Text('web_delete_account'.tr()),
                          subtitle:
                              Text('web_delete_account_sub'.tr()),
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.grey),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  title: Text('web_delete_account'.tr()),
                                  content: Text(
                                      'web_delete_account_confirm'.tr()),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('cancel'.tr()),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        final id = _numericStaffId;
                                        final success = id != null &&
                                            await WebApiService.deleteUser(id,
                                                deletedBy: widget.userName);
                                        if (!mounted) return;
                                        if (!success) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'web_account_deletion_failed'.tr()),
                                                backgroundColor: Colors.red),
                                          );
                                          return;
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'web_account_deletion_submitted'.tr()),
                                              backgroundColor: Colors.red),
                                        );
                                        await WebSession.clear();
                                        if (!mounted) return;
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const WebLogin()),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red),
                                      child: Text('delete_button'.tr()),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                isEditing = false;
                                _nameController.text = widget.userName;
                                _emailController.text = widget.userEmail;
                              });
                              _loadPhoneFromApi();
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('cancel'.tr(),
                                style: const TextStyle(color: Colors.red)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A56DB),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('web_save_changes'.tr()),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A56DB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1A56DB), size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    bool isEditing = false,
    TextEditingController? controller,
    bool isReadOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: isEditing && controller != null
                ? TextFormField(
                    controller: controller,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: UnderlineInputBorder(),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
          ),
        ],
      ),
    );
  }
}
