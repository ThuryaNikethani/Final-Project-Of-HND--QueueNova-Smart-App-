import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
      'online_service_requests',
      'document_management',
      'account_deletion_requests',
      'notification_delivery_log',
      'notification_history',
    ],
    UserRole.reception: [
      'dashboard',
      'reception',
      'appointments',
      'notification_history',
    ],
    UserRole.departmentManager: [
      'dashboard',
      'analytics',
      'reports',
      'staff_performance',
      'payment_reports',
      'document_management',  // ← ADDED
      'online_service_requests',
      'notification_history',
    ],
  };

  static String getRoleName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'web_role_admin'.tr();
      case UserRole.queueManager:
        return 'web_role_queue_manager'.tr();
      case UserRole.serviceProcessor:
        return 'web_role_service_officer'.tr();
      case UserRole.reception:
        return 'web_role_reception_officer'.tr();
      case UserRole.departmentManager:
        return 'web_role_department_manager'.tr();
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