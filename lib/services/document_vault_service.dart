import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentModel {
  final String id;
  final String name;
  final String type;
  final String url;
  final DateTime uploadDate;
  final List<String> sharedWith;

  DocumentModel({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.uploadDate,
    required this.sharedWith,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'url': url,
    'uploadDate': uploadDate.toIso8601String(),
    'sharedWith': sharedWith,
  };

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
    id: json['id'],
    name: json['name'],
    type: json['type'],
    url: json['url'],
    uploadDate: DateTime.parse(json['uploadDate']),
    sharedWith: List<String>.from(json['sharedWith']),
  );
}

class DocumentVaultService {
  static const String _documentsKey = 'user_documents';
  static List<DocumentModel> _documents = [];

  static Future<List<DocumentModel>> getDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? docsJson = prefs.getString(_documentsKey);
    if (docsJson != null && docsJson.isNotEmpty) {
      final List<dynamic> docs = jsonDecode(docsJson);
      _documents = docs.map((d) => DocumentModel.fromJson(d)).toList();
    } else {
      _documents = [];
    }
    return _documents;
  }

  static Future<void> addDocument(DocumentModel document) async {
    _documents.add(document);
    await _saveDocuments();
  }

  static Future<void> removeDocument(String docId) async {
    _documents.removeWhere((d) => d.id == docId);
    await _saveDocuments();
  }

  static Future<void> shareDocument(String docId, String departmentId) async {
    final index = _documents.indexWhere((d) => d.id == docId);
    if (index != -1 && !_documents[index].sharedWith.contains(departmentId)) {
      _documents[index].sharedWith.add(departmentId);
      await _saveDocuments();
    }
  }

  static Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final String docsJson = jsonEncode(_documents.map((d) => d.toJson()).toList());
    await prefs.setString(_documentsKey, docsJson);
  }
}