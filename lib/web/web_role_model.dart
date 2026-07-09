import 'package:flutter/material.dart';

enum UserRole {
  admin,
  queueManager,
  serviceProcessor,
  reception,
  departmentManager,
}

class RolePermissions {
  static const Map<UserRole, List<String>> permissions = {
    UserRole.admin: [
      'dashboard',
      'user_management',
      'analytics',
      'reports',
      'system_settings',
      'staff_performance',
      'security_settings',
      'backup_restore',
      'audit_logs',
      'system_health',
      'payment_reports',
      'document_management',  // ← ADDED
      'account_deletion_requests',
      'notification_delivery_log',
      'notification_history',
    ],
    UserRole.queueManager: [
      'dashboard',
      'queue_management',
      'document_management',  // ← ADDED
      'notification_history',
    ],
    UserRole.serviceProcessor: [
      'dashboard',
      'service_processing',
      'document_management',
      'account_deletion_requests',
      'notification_delivery_log',
      'notification_history',
    ],
    UserRole.reception: [
      'dashboard',
      'reception',
      'appointments',
      'document_management',  // ← ADDED
      'notification_history',
    ],
    UserRole.departmentManager: [
      'dashboard',
      'analytics',
      'reports',
      'staff_performance',
      'payment_reports',
      'document_management',  // ← ADDED
      'notification_history',
    ],
  };

  static String getRoleName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'System Administrator';
      case UserRole.queueManager:
        return 'Queue Management Officer';
      case UserRole.serviceProcessor:
        return 'Service Processing Officer';
      case UserRole.reception:
        return 'Reception Officer';
      case UserRole.departmentManager:
        return 'Department Manager';
    }
  }

  static Color getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const Color(0xFF1A56DB);
      case UserRole.queueManager:
        return const Color(0xFF10B981);
      case UserRole.serviceProcessor:
        return const Color(0xFFF59E0B);
      case UserRole.reception:
        return const Color(0xFF8B5CF6);
      case UserRole.departmentManager:
        return const Color(0xFF06B6D4);
    }
  }
}