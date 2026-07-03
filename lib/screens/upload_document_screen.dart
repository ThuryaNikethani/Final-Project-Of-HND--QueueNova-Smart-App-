import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/document_vault_service.dart';

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

  Future<void> _showUploadOptions() async {
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
            const Text(
              'Upload Document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildUploadOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: AppColors.primaryBlue,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                _buildUploadOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: AppColors.success,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _buildUploadOption(
                  icon: Icons.insert_drive_file,
                  label: 'File',
                  color: AppColors.warning,
                  onTap: () => _pickFile(),
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
                        'On web, camera opens file picker. For best camera experience, use Android app.',
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

  Future<void> _pickImage(ImageSource source) async {
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
        await _uploadFile(file);
      } else {
        setState(() => isUploading = false);
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() => isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture image. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      setState(() => isUploading = true);

      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (file != null) {
        await _uploadFile(file);
      } else {
        setState(() => isUploading = false);
      }
    } catch (e) {
      print('Error picking file: $e');
      setState(() => isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick file. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadFile(XFile file) async {
    await Future.delayed(const Duration(seconds: 1));

    final newDoc = DocumentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: file.name,
      type: file.path.split('.').last.toUpperCase(),
      url: file.path,
      uploadDate: DateTime.now(),
      sharedWith: [],
    );
    await DocumentVaultService.addDocument(newDoc);

    setState(() {
      uploadedDocs.insert(0, {
        'name': file.name,
        'type': file.path.split('.').last.toUpperCase(),
        'date': DateTime.now(),
        'category': _detectCategory(file.name),
      });
      isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document uploaded successfully'),
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
        title: const Text('Upload Document'),
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
                    const SnackBar(
                        content: Text('All documents cleared'),
                        backgroundColor: AppColors.warning),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'clear', child: Text('Clear All')),
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
                      isUploading ? 'Uploading...' : 'Tap to Upload Document',
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
                          children: const [
                            Icon(Icons.photo_library,
                                size: 14, color: Colors.white70),
                            SizedBox(width: 4),
                            Text('Gallery',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.camera_alt,
                                size: 14, color: Colors.white70),
                            SizedBox(width: 4),
                            Text('Camera',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.insert_drive_file,
                                size: 14, color: Colors.white70),
                            SizedBox(width: 4),
                            Text('File',
                                style: TextStyle(
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
            const Text(
              'Quick Upload',
              style: TextStyle(
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
                    Icons.badge, 'NIC', const Color(0xFF1A56DB)),
                _buildQuickUploadItem(
                    Icons.airplane_ticket, 'Passport', const Color(0xFF10B981)),
                _buildQuickUploadItem(
                    Icons.directions_car, 'License', const Color(0xFFF59E0B)),
                _buildQuickUploadItem(
                    Icons.description, 'Other', const Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 24),
            if (uploadedDocs.isNotEmpty) ...[
              const Text(
                'Filter by Category',
                style: TextStyle(
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
                      label: Text(category),
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
                  const Text(
                    'My Documents',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937)),
                  ),
                  Text(
                    '${filteredDocs.length} items',
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
                                      doc['category'],
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: AppColors.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${doc['type']} • ${_formatDate(doc['date'])}',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.grey),
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
                      'No documents uploaded yet',
                      style: TextStyle(color: AppColors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the upload area to get started',
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

  Widget _buildQuickUploadItem(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _showUploadOptions(),
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
