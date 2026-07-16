import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/backend_config.dart';

class DocumentModel {
  final String id;
  final String name;
  final String type;
  final String url;
  final DateTime uploadDate;
  final List<String> sharedWith;
  final String category;

  DocumentModel({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.uploadDate,
    required this.sharedWith,
    this.category = 'Other',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'url': url,
    'uploadDate': uploadDate.toIso8601String(),
    'sharedWith': sharedWith,
    'category': category,
  };

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
    id: json['id'].toString(),
    name: json['name'],
    type: json['type'],
    url: json['url'],
    uploadDate: DateTime.parse(json['uploadDate']),
    sharedWith: List<String>.from(json['sharedWith']),
    category: json['category'] as String? ?? 'Other',
  );
}

/// Citizen-side document storage, backed by the same PostgreSQL `documents`
/// table (and `/api/web/documents/*` endpoints) the officer's Service
/// Processing / Document Management dashboards already read and write.
///
/// Previously this stored documents purely locally, keyed by a browser
/// blob: URL on web — those URLs only live for the current page load, so
/// every reload/restart silently broke every previously "saved" preview.
/// Uploading to the backend gives every document a real, permanent URL
/// (`/api/web/documents/download/:id`) that works the same way on web and
/// mobile, and survives reloads, restarts, and even switching devices.
class DocumentVaultService {
  static const String _cacheKey = 'user_documents_cache';

  static Future<String> _myNic() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('userNIC') ?? '').toUpperCase();
  }

  static DocumentModel _fromRow(Map<String, dynamic> row) {
    final id = row['id'].toString();
    final name = row['document_name'] as String? ?? 'document';
    final type = name.contains('.') ? name.split('.').last.toUpperCase() : '';
    return DocumentModel(
      id: id,
      name: name,
      type: type,
      url: '${BackendConfig.baseUrl}/api/web/documents/download/$id',
      uploadDate: DateTime.tryParse(row['uploaded_at']?.toString() ?? '') ?? DateTime.now(),
      sharedWith: List<String>.from(row['shared_with'] as List? ?? const []),
      category: row['document_type'] as String? ?? 'Other',
    );
  }

  static Future<List<DocumentModel>> getDocuments() async {
    try {
      final nic = await _myNic();
      final res = await http
          .get(Uri.parse('${BackendConfig.baseUrl}/api/web/documents'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final rows = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      final docs = rows
          .where((r) => ((r['citizen_nic'] as String?) ?? '').toUpperCase() == nic)
          .map(_fromRow)
          .toList();
      await _saveCache(docs);
      return docs;
    } catch (e) {
      debugPrint('DocumentVaultService.getDocuments failed: $e — using local cache');
      return _loadCache();
    }
  }

  static Future<DocumentModel?> uploadDocument(XFile file, String category, {String? description}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nic = prefs.getString('userNIC') ?? '';
      final name = prefs.getString('userName') ?? '';
      final bytes = await file.readAsBytes();

      // The server derives document_name from the uploaded file's own
      // filename — swapping in a description here (keeping the real
      // extension so type/preview detection still works) is enough to
      // rename it, no server changes needed.
      var uploadName = file.name;
      if (description != null && description.trim().isNotEmpty) {
        final ext = file.name.contains('.') ? file.name.split('.').last : '';
        uploadName = ext.isNotEmpty ? '${description.trim()}.$ext' : description.trim();
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${BackendConfig.baseUrl}/api/web/documents/upload'),
      )
        ..fields['citizenName'] = name
        ..fields['citizenNic'] = nic
        ..fields['documentType'] = category
        ..fields['uploadedBy'] = name
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: uploadName));

      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        debugPrint('DocumentVaultService.uploadDocument failed (${streamed.statusCode}): $body');
        return null;
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return _fromRow(decoded['document'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('DocumentVaultService.uploadDocument error: $e');
      return null;
    }
  }

  static Future<void> removeDocument(String docId) async {
    try {
      await http
          .delete(Uri.parse('${BackendConfig.baseUrl}/api/web/documents/$docId'))
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('DocumentVaultService.removeDocument failed: $e');
    }
  }

  static Future<void> shareDocument(String docId, List<String> currentShared, String departmentId) async {
    if (currentShared.contains(departmentId)) return;
    final updated = [...currentShared, departmentId];
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('userName') ?? '';
      await http.patch(
        Uri.parse('${BackendConfig.baseUrl}/api/web/documents/$docId/share'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'departments': updated, 'sharedBy': name}),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('DocumentVaultService.shareDocument failed: $e');
    }
  }

  static Future<void> _saveCache(List<DocumentModel> docs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(docs.map((d) => d.toJson()).toList()));
  }

  static Future<List<DocumentModel>> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((d) => DocumentModel.fromJson(d)).toList();
  }
}
