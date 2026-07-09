import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/document_vault_service.dart';

const Map<String, String> _kDepartmentKeys = {
  'RMV': 'dept_rmv',
  'Divisional Secretariat': 'dept_divisional_secretariat',
  'Passport Office': 'dept_passport_office',
  'Registration Department': 'dept_registration_department',
};

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  List<DocumentModel> documents = [];
  bool isLoading = true;

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
                await DocumentVaultService.shareDocument(doc.id, dept);
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getFileColor(doc.type),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(_getFileIcon(doc.type), color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('${doc.type} • ${doc.uploadDate.day}/${doc.uploadDate.month}/${doc.uploadDate.year}', style: TextStyle(fontSize: 12, color: AppColors.grey)),
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
                          IconButton(
                            icon: const Icon(Icons.share, color: AppColors.primaryBlue),
                            onPressed: () => _shareDocument(doc),
                          ),
                        ],
                      ),
                    );
                  },
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