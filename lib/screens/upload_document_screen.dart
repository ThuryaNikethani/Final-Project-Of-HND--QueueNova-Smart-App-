import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/document_vault_service.dart';

const Map<String, String> _kDocCategoryKeys = {
  'All': 'filter_all',
  'NIC': 'nic_category',
  'Passport': 'passport',
  'License': 'category_license',
  'Birth': 'birth',
  'Other': 'category_other',
};

// Note: dart:html is NOT needed for web file picking
// ImagePicker works on all platforms including web

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final List<Map<String, dynamic>> uploadedDocs = [];
  bool isUploading = false;
  String selectedCategory = 'All';

  final List<String> categories = [
    'All',
    'NIC',
    'Passport',
    'License',
    'Birth',
    'Other'
  ];

  bool get isWeb => kIsWeb;

  Future<void> _showUploadOptions([String? presetCategory]) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'upload_document'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildUploadOption(
                  icon: Icons.photo_library,
                  label: 'gallery_label'.tr(),
                  color: AppColors.primaryBlue,
                  onTap: () => _pickImage(ImageSource.gallery, presetCategory),
                ),
                _buildUploadOption(
                  icon: Icons.camera_alt,
                  label: 'camera_label'.tr(),
                  color: AppColors.success,
                  onTap: () => _pickImage(ImageSource.camera, presetCategory),
                ),
                _buildUploadOption(
                  icon: Icons.insert_drive_file,
                  label: 'file_label'.tr(),
                  color: AppColors.warning,
                  onTap: () => _pickFile(presetCategory),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isWeb)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'web_camera_notice'.tr(),
                        style:
                            TextStyle(fontSize: 10, color: AppColors.warning),
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

  Widget _buildUploadOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, [String? presetCategory]) async {
    try {
      setState(() => isUploading = true);

      XFile? file;

      final picker = ImagePicker();

      // On web, camera and gallery both work via file picker
      // On mobile, camera opens actual camera
      file = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (file != null) {
        await _uploadFile(file, presetCategory);
      } else {
        setState(() => isUploading = false);
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() => isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('capture_image_failed'.tr()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFile([String? presetCategory]) async {
    try {
      setState(() => isUploading = true);

      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (file != null) {
        await _uploadFile(file, presetCategory);
      } else {
        setState(() => isUploading = false);
      }
    } catch (e) {
      print('Error picking file: $e');
      setState(() => isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pick_file_failed'.tr()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // "Other" doesn't say what the document actually is, unlike NIC/Passport/
  // License/Birth — ask the citizen to label it so the vault entry means
  // something later instead of just showing a generic filename.
  Future<String?> _promptOtherDescription() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('document_description_prompt_title'.tr()),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: 'document_description_hint'.tr()),
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text.trim()),
              child: Text('upload_document'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFile(XFile file, [String? presetCategory]) async {
    final category = presetCategory ?? _detectCategory(file.name);

    String? description;
    if (category == 'Other') {
      if (!mounted) return;
      description = await _promptOtherDescription();
      if (description == null) {
        // Citizen cancelled the description prompt — abort the upload
        // rather than silently saving an unlabeled "Other" document.
        setState(() => isUploading = false);
        return;
      }
    }

    // Uploads straight to the backend now (not a local blob: URL) so the
    // document has a real, permanent URL that survives page reloads and
    // works identically on web and mobile.
    final newDoc = await DocumentVaultService.uploadDocument(file, category, description: description);

    if (!mounted) return;

    if (newDoc == null) {
      setState(() => isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('document_upload_failed'.tr()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      uploadedDocs.insert(0, {
        'name': newDoc.name,
        'type': newDoc.type,
        'date': newDoc.uploadDate,
        'category': newDoc.category,
      });
      isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('document_uploaded_successfully'.tr()),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _detectCategory(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.contains('nic')) return 'NIC';
    if (lowerName.contains('passport')) return 'Passport';
    if (lowerName.contains('license') || lowerName.contains('driving'))
      return 'License';
    if (lowerName.contains('birth')) return 'Birth';
    return 'Other';
  }

  List<Map<String, dynamic>> get filteredDocs {
    if (selectedCategory == 'All') return uploadedDocs;
    return uploadedDocs
        .where((doc) => doc['category'] == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('upload_document'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (uploadedDocs.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'clear') {
                  setState(() {
                    uploadedDocs.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('all_documents_cleared'.tr()),
                        backgroundColor: AppColors.warning),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'clear', child: Text('clear_all_button'.tr())),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InkWell(
              onTap: _showUploadOptions,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        isUploading
                            ? Icons.hourglass_empty
                            : Icons.cloud_upload,
                        size: 55,
                        color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      isUploading ? 'uploading_label'.tr() : 'tap_to_upload_document'.tr(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text('gallery_label'.tr(),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text('camera_label'.tr(),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.insert_drive_file,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text('file_label'.tr(),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'quick_upload'.tr(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: [
                _buildQuickUploadItem(
                    Icons.badge, 'nic_category'.tr(), const Color(0xFF1A56DB), 'NIC'),
                _buildQuickUploadItem(
                    Icons.airplane_ticket, 'passport'.tr(), const Color(0xFF10B981), 'Passport'),
                _buildQuickUploadItem(
                    Icons.directions_car, 'category_license'.tr(), const Color(0xFFF59E0B), 'License'),
                _buildQuickUploadItem(
                    Icons.description, 'category_other'.tr(), const Color(0xFF8B5CF6), 'Other'),
              ],
            ),
            const SizedBox(height: 24),
            if (uploadedDocs.isNotEmpty) ...[
              Text(
                'filter_by_category'.tr(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 12),
              Container(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = selectedCategory == category;
                    return FilterChip(
                      label: Text(_kDocCategoryKeys[category]!.tr()),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => selectedCategory = category),
                      selectedColor: AppColors.primaryBlue,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (uploadedDocs.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'my_documents'.tr(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937)),
                  ),
                  Text(
                    'items_count'.tr(args: ['${filteredDocs.length}']),
                    style: TextStyle(fontSize: 12, color: AppColors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _getFileColor(doc['type']),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_getFileIcon(doc['type']),
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightBlue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _kDocCategoryKeys[doc['category']]!.tr(),
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: AppColors.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${doc['type']} • ${_formatDate(doc['date'])}',
                                      style: TextStyle(
                                          fontSize: 11, color: AppColors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.error),
                          onPressed: () {
                            setState(() {
                              uploadedDocs.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ] else if (!isUploading) ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open,
                        size: 64, color: AppColors.grey.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'no_documents_uploaded_yet'.tr(),
                      style: TextStyle(color: AppColors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'tap_upload_area_hint'.tr(),
                      style: TextStyle(fontSize: 12, color: AppColors.grey),
                    ),
                  ],
                ),
              ),
            ],
            if (isUploading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickUploadItem(IconData icon, String label, Color color, String category) {
    return GestureDetector(
      onTap: () => _showUploadOptions(category),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  IconData _getFileIcon(String type) {
    if (type == 'PDF') return Icons.picture_as_pdf;
    if (type == 'JPG' || type == 'PNG') return Icons.image;
    if (type == 'DOC') return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String type) {
    if (type == 'PDF') return Colors.red;
    if (type == 'JPG' || type == 'PNG') return Colors.green;
    if (type == 'DOC') return Colors.orange;
    return AppColors.primaryBlue;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
