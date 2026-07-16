import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/document_vault_service.dart';

const Map<String, String> _kDepartmentKeys = {
  'RMV': 'dept_rmv',
  'Divisional Secretariat': 'dept_divisional_secretariat',
  'Passport Office': 'dept_passport_office',
  'Registration Department': 'dept_registration_department',
};

const Map<String, String> _kVaultCategoryKeys = {
  'All': 'filter_all',
  'NIC': 'nic_category',
  'Passport': 'passport',
  'License': 'category_license',
  'Birth': 'birth',
  'Other': 'category_other',
};

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  List<DocumentModel> documents = [];
  bool isLoading = true;
  String selectedCategory = 'All';
  // Matches the Quick Upload categories on the Upload Document screen
  // exactly (NIC/Passport/License/Other — there's no "Birth" upload tile).
  final List<String> categories = ['All', 'NIC', 'Passport', 'License', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => isLoading = true);
    final docs = await DocumentVaultService.getDocuments();
    setState(() {
      documents = docs;
      isLoading = false;
    });
  }

  List<DocumentModel> get filteredDocuments {
    if (selectedCategory == 'All') return documents;
    return documents.where((d) => _normalizedCategory(d) == selectedCategory).toList();
  }

  // doc.category comes straight from the backend's document_type column,
  // which also holds values from unrelated flows (appointment attachment
  // types like "NIC Copy", or the upload endpoint's 'General' default) that
  // don't match any of this screen's known category keys — falls back to
  // 'Other' instead of crashing on a missing translation lookup.
  String _normalizedCategory(DocumentModel doc) {
    return _kVaultCategoryKeys.containsKey(doc.category) ? doc.category : 'Other';
  }

  // Matches the icon/color pairing used by the Quick Upload tiles on the
  // Upload Document screen, so the same category reads the same way here.
  IconData _categoryIcon(String category) {
    switch (category) {
      case 'NIC': return Icons.badge;
      case 'Passport': return Icons.airplane_ticket;
      case 'License': return Icons.directions_car;
      case 'Other': return Icons.description;
      default: return Icons.grid_view_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'NIC': return const Color(0xFF1A56DB);
      case 'Passport': return const Color(0xFF10B981);
      case 'License': return const Color(0xFFF59E0B);
      case 'Other': return const Color(0xFF8B5CF6);
      default: return AppColors.primaryBlue;
    }
  }

  // doc.type used to be derived from the picked file's path, which is a
  // blob: URL with no real extension on web — documents uploaded before that
  // was fixed have their stored type permanently set to that garbled blob
  // string. The filename always had the right extension, so prefer that.
  String _realType(DocumentModel doc) {
    if (doc.name.contains('.')) return doc.name.split('.').last.toUpperCase();
    return doc.type;
  }

  bool _isImageType(String type) {
    final t = type.toLowerCase();
    return t == 'jpg' || t == 'jpeg' || t == 'png';
  }

  Widget _brokenPreview() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image, color: Colors.white70, size: 48),
        const SizedBox(height: 12),
        Text(
          'document_preview_unavailable'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _viewDocument(DocumentModel doc) async {
    if (_isImageType(_realType(doc))) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(32),
                  constraints: const BoxConstraints(minHeight: 160, minWidth: 160),
                  // doc.url is now always a real backend URL
                  // (/api/web/documents/download/:id), not a browser blob:
                  // URL, so it loads the same way on web and mobile.
                  child: Image.network(
                    doc.url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _brokenPreview(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Non-image types (PDF/DOC/etc.) have no in-app preview — open with the
    // device's own viewer instead of failing silently.
    final uri = Uri.tryParse(doc.url);
    final opened = uri != null && await canLaunchUrl(uri) && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('cannot_preview_document'.tr()), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _shareDocument(DocumentModel doc) async {
    final List<String> departments = ['RMV', 'Divisional Secretariat', 'Passport Office', 'Registration Department'];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('share_document_with'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...departments.map((dept) => ListTile(
              leading: const Icon(Icons.business, color: AppColors.primaryBlue),
              title: Text(_kDepartmentKeys[dept]!.tr()),
              onTap: () async {
                await DocumentVaultService.shareDocument(doc.id, doc.sharedWith, dept);
                Navigator.pop(context);
                await _loadDocuments();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('document_shared_with'.tr(args: [_kDepartmentKeys[dept]!.tr()])), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                  );
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('document_vault'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open, size: 80, color: AppColors.grey),
                      const SizedBox(height: 16),
                      Text('no_documents_yet'.tr(), style: const TextStyle(color: AppColors.grey)),
                      const SizedBox(height: 8),
                      Text('upload_documents_from_home'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 106,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = selectedCategory == category;
                          final tileColor = _categoryColor(category);
                          return GestureDetector(
                            onTap: () => setState(() => selectedCategory = category),
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [tileColor, tileColor.withOpacity(0.7)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: tileColor.withOpacity(isSelected ? 0.55 : 0.3),
                                            blurRadius: isSelected ? 14 : 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(_categoryIcon(category), color: Colors.white, size: 28),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.check_circle, color: tileColor, size: 18),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _kVaultCategoryKeys[category]!.tr(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredDocuments.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocuments[index];
                          final fileColor = _getFileColor(_realType(doc));
                          return InkWell(
                            onTap: () => _viewDocument(doc),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [fileColor, fileColor.withOpacity(0.7)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(color: fileColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                                      ],
                                    ),
                                    child: Icon(_getFileIcon(_realType(doc)), color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(doc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.lightBlue,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(_kVaultCategoryKeys[_normalizedCategory(doc)]!.tr(), style: TextStyle(fontSize: 9, color: AppColors.primaryBlue)),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                '${_realType(doc)} • ${doc.uploadDate.day}/${doc.uploadDate.month}/${doc.uploadDate.year}',
                                                style: TextStyle(fontSize: 12, color: AppColors.grey),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (doc.sharedWith.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text('shared_with_departments_count'.tr(args: ['${doc.sharedWith.length}']), style: const TextStyle(fontSize: 10, color: AppColors.success)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.lightBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.share, color: AppColors.primaryBlue, size: 20),
                                      onPressed: () => _shareDocument(doc),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'jpg': return Icons.image;
      case 'png': return Icons.image;
      case 'doc': return Icons.description;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf': return Colors.red;
      case 'jpg': return Colors.green;
      case 'png': return Colors.blue;
      case 'doc': return Colors.orange;
      default: return AppColors.primaryBlue;
    }
  }
}