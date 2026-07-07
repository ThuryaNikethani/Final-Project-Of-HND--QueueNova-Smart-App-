import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:queuenova_mobile/firebase_options.dart';
import 'web_login.dart';
import 'web_account_deletion_requests.dart';
import 'web_notification_delivery_log.dart';
import 'web_components/web_sidebar.dart';
import 'web_components/modern_ui_components.dart';
import 'web_queue_management.dart';
import 'web_service_processing.dart';
import 'web_reception.dart';
import 'web_analytics.dart';
import 'web_users_management.dart';
import 'web_reports.dart';
import 'web_document_management.dart';
import 'web_appointments.dart';
import 'web_system_settings.dart';
import 'web_staff_performance.dart';
import 'web_security_settings.dart';
import 'web_backup_restore.dart';
import 'web_audit_logs.dart';
import 'web_system_health.dart';
import 'web_profile.dart';
import 'web_payment_reports.dart';
import 'web_role_model.dart';
import 'web_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // The dashboard has its own demo login (web_login.dart) and doesn't
  // otherwise use Firebase Auth — sign in anonymously purely so Firestore
  // security rules requiring request.auth != null are satisfied. This must
  // not block startup: if Anonymous sign-in isn't enabled in the Firebase
  // project, the dashboard should still render rather than show a blank
  // white screen.
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed (dashboard will still load): $e');
    }
  }
  runApp(const WebQueueNovaApp());
}

class WebQueueNovaApp extends StatelessWidget {
  const WebQueueNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QueueNova Pulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1A56DB),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1A56DB),
          secondary: Color(0xFF7C3AED),
          tertiary: Color(0xFF06B6D4),
          surface: Color(0xFFFFFFFF),
          background: Color(0xFFF5F7FA),
          error: Color(0xFFDC2626),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1F2937)),
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
            letterSpacing: 0.5,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2),
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A56DB),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1A56DB),
            side: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE5E7EB),
          thickness: 1,
          space: 16,
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const WebLogin(),
      },
    );
  }
}

class WebDashboard extends StatefulWidget {
  final UserRole userRole;
  final String userName;
  final String userEmail;
  final String userId;

  const WebDashboard({
    super.key,
    required this.userRole,
    required this.userName,
    required this.userEmail,
    required this.userId,
  });

  @override
  State<WebDashboard> createState() => _WebDashboardState();
}

class _WebDashboardState extends State<WebDashboard> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _menuItems = [];

  @override
  void initState() {
    super.initState();
    _updateMenuItems();
  }

  void _updateMenuItems() {
    final permissions = RolePermissions.permissions[widget.userRole] ?? [];
    final allItems = [
      {
        'widget': DashboardHome(userRole: widget.userRole, staffId: widget.userId),
        'permission': 'dashboard',
        'label': 'Dashboard',
        'icon': Icons.dashboard
      },
      {
        'widget': const WebQueueManagement(),
        'permission': 'queue_management',
        'label': 'Queue Management',
        'icon': Icons.queue
      },
      {
        'widget': const WebServiceProcessing(),
        'permission': 'service_processing',
        'label': 'Service Processing',
        'icon': Icons.assignment
      },
      {
        'widget': const WebReception(),
        'permission': 'reception',
        'label': 'Reception',
        'icon': Icons.qr_code_scanner
      },
      {
        'widget': const WebDocumentManagement(),
        'permission': 'document_management',
        'label': 'Documents',
        'icon': Icons.description
      },
      {
        'widget': WebAccountDeletionRequests(officerName: widget.userName),
        'permission': 'account_deletion_requests',
        'label': 'Account Deletion Requests',
        'icon': Icons.person_remove
      },
      {
        'widget': const WebNotificationDeliveryLog(),
        'permission': 'notification_delivery_log',
        'label': 'Notification Delivery Log',
        'icon': Icons.mark_email_read
      },
      {
        'widget': const WebAppointments(),
        'permission': 'appointments',
        'label': 'Appointments',
        'icon': Icons.calendar_today
      },
      {
        'widget': const WebUsersManagement(),
        'permission': 'user_management',
        'label': 'Users',
        'icon': Icons.people
      },
      {
        'widget': const WebAnalytics(),
        'permission': 'analytics',
        'label': 'Analytics',
        'icon': Icons.analytics
      },
      {
        'widget': const WebReports(),
        'permission': 'reports',
        'label': 'Reports',
        'icon': Icons.receipt
      },
      {
        'widget': const WebSystemSettings(),
        'permission': 'system_settings',
        'label': 'System Settings',
        'icon': Icons.settings
      },
      {
        'widget': const WebStaffPerformance(),
        'permission': 'staff_performance',
        'label': 'Staff Performance',
        'icon': Icons.people_outline
      },
      {
        'widget': const WebSecuritySettings(),
        'permission': 'security_settings',
        'label': 'Security',
        'icon': Icons.security
      },
      {
        'widget': const WebBackupRestore(),
        'permission': 'backup_restore',
        'label': 'Backup & Restore',
        'icon': Icons.backup
      },
      {
        'widget': const WebAuditLogs(),
        'permission': 'audit_logs',
        'label': 'Audit Logs',
        'icon': Icons.history
      },
      {
        'widget': const WebSystemHealth(),
        'permission': 'system_health',
        'label': 'System Health',
        'icon': Icons.health_and_safety
      },
      {
        'widget': const WebPaymentReports(),
        'permission': 'payment_reports',
        'label': 'Payment Reports',
        'icon': Icons.payment
      },
    ];

    _menuItems = allItems
        .where((item) => permissions.contains(item['permission']))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_menuItems.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No permissions assigned for this role'),
        ),
      );
    }

    final pages = _menuItems.map((item) => item['widget'] as Widget).toList();

    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF5F7FA),
              const Color(0xFFF5F7FA).withOpacity(0.95),
            ],
          ),
        ),
        child: Row(
          children: [
            WebSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              userRole: widget.userRole,
              userName: widget.userName,
              userEmail: widget.userEmail,
              menuItems: _menuItems,
            ),
            Expanded(
              child: pages[_selectedIndex],
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  final UserRole userRole;
  final String staffId;

  const DashboardHome({super.key, required this.userRole, required this.staffId});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  int _notificationCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<QuerySnapshot>? _notifSub;

  @override
  void initState() {
    super.initState();
    // Sorted client-side (rather than orderBy in the query) to avoid needing
    // a Firestore composite index for an arrayContains + orderBy combination.
    _notifSub = FirebaseFirestore.instance
        .collection('staff_notifications')
        .where('targetRoles', arrayContains: widget.userRole.name)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aTime = a.data()['createdAt'] as Timestamp?;
          final bTime = b.data()['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
      setState(() {
        _notifications = docs
            .map((d) => _toDisplayNotif(d.id, d.data()))
            .where((n) => !(n['dismissed'] as bool))
            .take(200)
            .toList();
        _notificationCount = _notifications.where((n) => n['read'] == false).length;
      });
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _toDisplayNotif(String id, Map<String, dynamic> data) {
    final readBy = (data['readBy'] as List?)?.cast<String>() ?? const [];
    final dismissedBy = (data['dismissedBy'] as List?)?.cast<String>() ?? const [];
    final createdAt = data['createdAt'] as Timestamp?;
    return {
      'id': id,
      'title': data['title'] as String? ?? '',
      'message': data['message'] as String? ?? '',
      'type': data['type'] as String? ?? 'system',
      'action': data['action'] as String? ?? 'View Details',
      'time': _relativeTime(createdAt?.toDate()),
      'read': readBy.contains(widget.staffId),
      'dismissed': dismissedBy.contains(widget.staffId),
    };
  }

  String _relativeTime(DateTime? time) {
    if (time == null) return '—';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  Future<void> _markAsRead(String id) async {
    await FirebaseFirestore.instance.collection('staff_notifications').doc(id).set({
      'readBy': FieldValue.arrayUnion([widget.staffId]),
    }, SetOptions(merge: true));
  }

  Future<void> _markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final n in _notifications.where((n) => n['read'] == false)) {
      batch.set(
        FirebaseFirestore.instance.collection('staff_notifications').doc(n['id'] as String),
        {'readBy': FieldValue.arrayUnion([widget.staffId])},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read'), backgroundColor: Colors.green),
    );
  }

  Future<void> _addTestNotification() async {
    await FirebaseFirestore.instance.collection('staff_notifications').add({
      'title': 'Test Notification',
      'message': 'This is a test notification to verify your settings are working correctly.',
      'type': 'system',
      'action': 'View Details',
      'targetRoles': [widget.userRole.name],
      'readBy': <String>[],
      'dismissedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showNotificationPanel() {
    final notificationsCopy = List<Map<String, dynamic>>.from(_notifications);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: SizedBox(
                width: 500,
                height: 600,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A56DB),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications, color: Colors.white),
                          const SizedBox(width: 10),
                          const Text(
                            'Notifications',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_notificationCount > 0)
                            TextButton(
                              onPressed: () async {
                                await _markAllAsRead();
                                setDialogState(() {
                                  for (var n in notificationsCopy) {
                                    n['read'] = true;
                                  }
                                });
                              },
                              child: const Text('Mark all read',
                                  style: TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: notificationsCopy.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_none,
                                      size: 80, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No notifications',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: notificationsCopy.length,
                              itemBuilder: (context, index) {
                                final notif = notificationsCopy[index];
                                final isRead = notif['read'] as bool;
                                return GestureDetector(
                                  onTap: () {
                                    if (!isRead) {
                                      _markAsRead(notif['id'] as String);
                                      setDialogState(() {
                                        notif['read'] = true;
                                      });
                                    }
                                    Navigator.pop(context);
                                    _navigateToNotificationDetail(notif);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? Colors.white
                                          : const Color(0xFFE8F0FE),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isRead
                                            ? Colors.grey.shade200
                                            : const Color(0xFF1A56DB),
                                        width: isRead ? 1 : 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _getNotificationColor(
                                                    notif['type'])
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getNotificationIcon(notif['type']),
                                            color: _getNotificationColor(
                                                notif['type']),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                notif['title'],
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: isRead
                                                      ? FontWeight.w500
                                                      : FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                notif['message'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                notif['time'],
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        const Icon(Icons.chevron_right,
                                            color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                            top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _addTestNotification();
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.send, size: 18),
                              label: const Text('Send Test Notification'),
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFF1A56DB)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToNotificationDetail(Map<String, dynamic> notif) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 500,
          height: 550,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getNotificationColor(notif['type']),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_getNotificationIcon(notif['type']),
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notif['title'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(notif['time'],
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          notif['message'],
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (notif['type'] == 'appointment') ...[
                        const Text('Appointment Details',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        _buildDetailRow('Service', notif['service']),
                        _buildDetailRow('Office', notif['office']),
                        _buildDetailRow('Date & Time', notif['datetime']),
                        _buildDetailRow('Token', notif['token']),
                      ],
                      if (notif['type'] == 'queue') ...[
                        const Text('Queue Details',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        _buildDetailRow('Token', notif['token']),
                        _buildDetailRow('Counter', notif['counter']),
                        _buildDetailRow('Estimated Wait', notif['waitTime']),
                        _buildDetailRow('People Ahead', notif['ahead']),
                      ],
                      if (notif['type'] == 'document') ...[
                        const Text('Document Details',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        _buildDetailRow('Document Name', notif['docName']),
                        _buildDetailRow('Status', notif['docStatus']),
                        _buildDetailRow('Uploaded By', notif['uploadedBy']),
                        _buildDetailRow('Submitted On', notif['submittedOn']),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (notif['action'] == 'View Appointment') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const WebAppointments()),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '${notif['action']} - Coming Soon'),
                                    backgroundColor: const Color(0xFF1A56DB)),
                              );
                            }
                          },
                          icon: Icon(_getActionIcon(notif['action'])),
                          label: Text(notif['action']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56DB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'appointment':
        return Colors.orange;
      case 'queue':
        return Colors.blue;
      case 'document':
        return Colors.purple;
      case 'system':
        return Colors.green;
      default:
        return const Color(0xFF1A56DB);
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'appointment':
        return Icons.calendar_today;
      case 'queue':
        return Icons.queue;
      case 'document':
        return Icons.description;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  IconData _getActionIcon(String action) {
    if (action.contains('View')) return Icons.visibility;
    if (action.contains('Review')) return Icons.rate_review;
    return Icons.arrow_forward;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState =
        context.findAncestorStateOfType<_WebDashboardState>();
    final userRole = dashboardState != null
        ? dashboardState.widget.userRole
        : UserRole.admin;
    final userName =
        dashboardState != null ? dashboardState.widget.userName : 'Admin User';
    final userEmail = dashboardState != null
        ? dashboardState.widget.userEmail
        : 'admin@queuenova.gov.lk';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none,
                          color: Colors.grey),
                      onPressed: _showNotificationPanel,
                    ),
                    if (_notificationCount > 0)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$_notificationCount',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                PopupMenuButton<String>(
                  offset: const Offset(0, 45),
                  onSelected: (value) {
                    if (value == 'profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebProfile(
                            userRole: userRole,
                            userName: userName,
                            userEmail: userEmail,
                          ),
                        ),
                      );
                    } else if (value == 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebSettings(
                            userRole: userRole,
                            userName: userName,
                            userEmail: userEmail,
                          ),
                        ),
                      );
                    } else if (value == 'logout') {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 18),
                          SizedBox(width: 10),
                          Text('My Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings, size: 18),
                          SizedBox(width: 10),
                          Text('Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Logout', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A56DB), Color(0xFF0E3A9B)],
                          ),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                                color: Color(0xFF1A56DB),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(RolePermissions.getRoleName(userRole),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ModernBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A56DB), Color(0xFF0E3A9B)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A56DB).withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, $userName',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Monitor and manage your queue system efficiently',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Help & Support coming soon'),
                              backgroundColor: Color(0xFF1A56DB)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.support_agent,
                            size: 32, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // First Row - 4 Stats
              LayoutBuilder(
                builder: (context, constraints) {
                  final spacing = constraints.maxWidth > 800 ? 16.0 : 12.0;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Total Services', '156',
                            Icons.assignment, Colors.blue),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard(
                            'Active Queues', '8', Icons.queue, Colors.green),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('Today\'s Appointments', '47',
                            Icons.calendar_today, Colors.orange),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('Pending Documents', '12',
                            Icons.description, Colors.red),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Second Row - 4 Stats
              LayoutBuilder(
                builder: (context, constraints) {
                  final spacing = constraints.maxWidth > 800 ? 16.0 : 12.0;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Total Citizens', '2,847',
                            Icons.people, Colors.purple),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('Services Completed', '1,234',
                            Icons.check_circle, Colors.teal),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('Avg. Satisfaction', '4.8',
                            Icons.star, Colors.amber),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('Avg. Response', '2.4min',
                            Icons.timer, Colors.indigo),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Bottom Row - Recent Activity and Quick Stats
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 900;

                  if (isSmallScreen) {
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Recent Activity',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _buildActivityItem('User checked in', '2 min ago',
                                  Icons.qr_code),
                              _buildActivityItem('Token A-024 called',
                                  '5 min ago', Icons.notifications),
                              _buildActivityItem('New appointment booked',
                                  '12 min ago', Icons.calendar_today),
                              _buildActivityItem('Document uploaded',
                                  '20 min ago', Icons.upload_file),
                              _buildActivityItem('Service completed',
                                  '35 min ago', Icons.check_circle),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Quick Stats',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _buildQuickStat("Today's Check-ins", '24',
                                  Icons.qr_code_scanner, Colors.blue),
                              const SizedBox(height: 12),
                              _buildQuickStat('Pending Approvals', '12',
                                  Icons.pending, Colors.orange),
                              const SizedBox(height: 12),
                              _buildQuickStat('Completed Services', '89',
                                  Icons.check_circle, Colors.green),
                              const SizedBox(height: 12),
                              _buildQuickStat('Active Users', '8', Icons.people,
                                  Colors.purple),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Recent Activity',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _buildActivityItem('User checked in', '2 min ago',
                                  Icons.qr_code),
                              const SizedBox(height: 8),
                              _buildActivityItem('Token A-024 called',
                                  '5 min ago', Icons.notifications),
                              const SizedBox(height: 8),
                              _buildActivityItem('New appointment booked',
                                  '12 min ago', Icons.calendar_today),
                              const SizedBox(height: 8),
                              _buildActivityItem('Document uploaded',
                                  '20 min ago', Icons.upload_file),
                              const SizedBox(height: 8),
                              _buildActivityItem('Service completed',
                                  '35 min ago', Icons.check_circle),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Quick Stats',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _buildQuickStat("Today's Check-ins", '24',
                                  Icons.qr_code_scanner, Colors.blue),
                              const SizedBox(height: 12),
                              _buildQuickStat('Pending Approvals', '12',
                                  Icons.pending, Colors.orange),
                              const SizedBox(height: 12),
                              _buildQuickStat('Completed Services', '89',
                                  Icons.check_circle, Colors.green),
                              const SizedBox(height: 12),
                              _buildQuickStat('Active Users', '8', Icons.people,
                                  Colors.purple),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.03), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: const Color(0xFF1A56DB)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13)),
                  Text(time,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}