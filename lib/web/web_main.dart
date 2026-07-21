import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:queuenova_mobile/firebase_options.dart';
import 'web_api_service.dart';
import 'web_session.dart';
import 'web_preferences_provider.dart';
import 'web_login.dart';
import 'web_account_deletion_requests.dart';
import 'web_notification_delivery_log.dart';
import 'web_notifications.dart';
import 'web_components/web_sidebar.dart';
import 'web_components/modern_ui_components.dart';
import 'web_queue_management.dart';
import 'web_service_processing.dart';
import 'web_online_service_requests.dart';
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
import 'web_feedback_list.dart';
import 'web_role_model.dart';
import 'web_settings_screen.dart';

/// Maps the Settings screen's 'selectedLanguage' preference value to an
/// easy_localization locale code.
String? _languageCodeFor(String? name) {
  switch (name) {
    case 'Sinhala':
      return 'si';
    case 'Tamil':
      return 'ta';
    case 'English':
      return 'en';
    default:
      return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
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
  // Restore a previously logged-in officer's session (if any) so a page
  // refresh doesn't drop them back to the login screen — only the
  // Logout button should do that.
  final restoredSession = await WebSession.load();
  debugPrint('[main] startup restoredSession = $restoredSession');

  // Seed theme/font/language from the officer's saved preferences (if any)
  // before the first frame, so returning users don't see a flash of the
  // default English/Light look before Settings loads.
  final preferencesProvider = WebPreferencesProvider();
  Locale startLocale = const Locale('en');
  final staffId = int.tryParse(restoredSession?['staffId'] as String? ?? '');
  if (staffId != null) {
    final prefs = await WebApiService.getUserPreferences(staffId);
    preferencesProvider.setThemeModeByName(prefs['selectedTheme'] as String? ?? '');
    preferencesProvider.setFontScaleByName(prefs['selectedFontSize'] as String? ?? '');
    final code = _languageCodeFor(prefs['selectedLanguage'] as String?);
    if (code != null) startLocale = Locale(code);
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: startLocale,
      child: ChangeNotifierProvider.value(
        value: preferencesProvider,
        child: WebQueueNovaApp(restoredSession: restoredSession),
      ),
    ),
  );
}

class WebQueueNovaApp extends StatelessWidget {
  final Map<String, dynamic>? restoredSession;

  const WebQueueNovaApp({super.key, this.restoredSession});

  @override
  Widget build(BuildContext context) {
    final session = restoredSession;
    final Widget initialScreen = session != null
        ? WebDashboard(
            userRole: session['userRole'] as UserRole,
            userName: session['userName'] as String,
            userEmail: session['userEmail'] as String,
            userId: session['staffId'] as String,
          )
        : const WebLogin();
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
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF3B82F6),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF9F7AEA),
          tertiary: Color(0xFF22D3EE),
          surface: Color(0xFF1E293B),
          error: Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFE5E7EB)),
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE5E7EB),
            letterSpacing: 0.5,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
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
            foregroundColor: const Color(0xFF3B82F6),
            side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
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
            side: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
          color: const Color(0xFF1E293B),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF334155),
          thickness: 1,
          space: 16,
        ),
      ),
      themeMode: context.watch<WebPreferencesProvider>().themeMode,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(context.watch<WebPreferencesProvider>().fontScale),
        ),
        child: child!,
      ),
      home: initialScreen,
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
  String? _photoBase64;

  // Security Settings → Session Security: auto-logout after N idle minutes,
  // enforced here (the one persistent shell every screen lives inside)
  // rather than in any individual page.
  Timer? _idleTimer;
  bool _sessionTimeoutEnabled = true;
  int _sessionTimeoutMinutes = 30;

  @override
  void initState() {
    super.initState();
    _updateMenuItems();
    _loadPhoto();
    _loadSessionTimeoutSettings();
  }

  Future<void> _loadSessionTimeoutSettings() async {
    final res = await WebApiService.getSecuritySettings();
    final settings = res?['settings'] as Map<String, dynamic>?;
    if (!mounted) return;
    _sessionTimeoutEnabled = settings?['enableSessionTimeout'] as bool? ?? true;
    _sessionTimeoutMinutes = settings?['sessionTimeoutMinutes'] as int? ?? 30;
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (!_sessionTimeoutEnabled) return;
    _idleTimer = Timer(Duration(minutes: _sessionTimeoutMinutes), _handleIdleTimeout);
  }

  Future<void> _handleIdleTimeout() async {
    if (!mounted) return;
    await WebSession.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WebLogin()),
    );
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    final id = int.tryParse(widget.userId);
    if (id == null) return;
    final users = await WebApiService.getUsers();
    final match = users.firstWhere((u) => u['id'] == id, orElse: () => {});
    if (!mounted || match.isEmpty) return;
    setState(() => _photoBase64 = match['photo_url'] as String?);
  }

  void _updateMenuItems() {
    final permissions = RolePermissions.permissions[widget.userRole] ?? [];
    final allItems = [
      {
        'widget': DashboardHome(userRole: widget.userRole, staffId: widget.userId, userName: widget.userName, onPhotoChanged: _loadPhoto),
        'permission': 'dashboard',
        'label': 'web_menu_dashboard',
        'icon': Icons.dashboard
      },
      {
        'widget': const WebQueueManagement(),
        'permission': 'queue_management',
        'label': 'web_menu_queue_management',
        'icon': Icons.queue
      },
      {
        'widget': const WebServiceProcessing(),
        'permission': 'service_processing',
        'label': 'web_menu_service_processing',
        'icon': Icons.assignment
      },
      {
        'widget': WebOnlineServiceRequests(userRole: widget.userRole, staffId: widget.userId, staffName: widget.userName),
        'permission': 'online_service_requests',
        'label': 'Online Requests',
        'icon': Icons.cloud_done
      },
      {
        'widget': WebReception(userRole: widget.userRole, staffId: widget.userId),
        'permission': 'reception',
        'label': 'web_menu_reception',
        'icon': Icons.qr_code_scanner
      },
      {
        'widget': const WebDocumentManagement(),
        'permission': 'document_management',
        'label': 'web_menu_documents',
        'icon': Icons.description
      },
      {
        'widget': WebAccountDeletionRequests(officerName: widget.userName),
        'permission': 'account_deletion_requests',
        'label': 'web_menu_account_deletion_requests',
        'icon': Icons.person_remove
      },
      {
        'widget': const WebNotificationDeliveryLog(),
        'permission': 'notification_delivery_log',
        'label': 'web_menu_notification_delivery_log',
        'icon': Icons.mark_email_read
      },
      {
        'widget': WebNotifications(userRole: widget.userRole, staffId: widget.userId),
        'permission': 'notification_history',
        'label': 'web_menu_notification_history',
        'icon': Icons.history_toggle_off
      },
      {
        'widget': WebAppointments(userRole: widget.userRole, staffId: widget.userId),
        'permission': 'appointments',
        'label': 'web_menu_appointments',
        'icon': Icons.calendar_today
      },
      {
        'widget': const WebUsersManagement(),
        'permission': 'user_management',
        'label': 'web_menu_users',
        'icon': Icons.people
      },
      {
        'widget': const WebAnalytics(),
        'permission': 'analytics',
        'label': 'web_menu_analytics',
        'icon': Icons.analytics
      },
      {
        'widget': const WebReports(),
        'permission': 'reports',
        'label': 'web_menu_reports',
        'icon': Icons.receipt
      },
      {
        'widget': const WebSystemSettings(),
        'permission': 'system_settings',
        'label': 'web_menu_system_settings',
        'icon': Icons.settings
      },
      {
        'widget': const WebStaffPerformance(),
        'permission': 'staff_performance',
        'label': 'web_menu_staff_performance',
        'icon': Icons.people_outline
      },
      {
        'widget': const WebSecuritySettings(),
        'permission': 'security_settings',
        'label': 'web_menu_security',
        'icon': Icons.security
      },
      {
        'widget': const WebBackupRestore(),
        'permission': 'backup_restore',
        'label': 'web_menu_backup_restore',
        'icon': Icons.backup
      },
      {
        'widget': const WebAuditLogs(),
        'permission': 'audit_logs',
        'label': 'web_menu_audit_logs',
        'icon': Icons.history
      },
      {
        'widget': const WebSystemHealth(),
        'permission': 'system_health',
        'label': 'web_menu_system_health',
        'icon': Icons.health_and_safety
      },
      {
        'widget': const WebPaymentReports(),
        'permission': 'payment_reports',
        'label': 'web_menu_payment_reports',
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
      return Scaffold(
        body: Center(
          child: Text('web_no_permissions'.tr()),
        ),
      );
    }

    final pages = _menuItems.map((item) => item['widget'] as Widget).toList();

    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerSignal: (_) => _resetIdleTimer(),
      child: Scaffold(
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
                photoBase64: _photoBase64,
                menuItems: _menuItems,
              ),
              Expanded(
                child: pages[_selectedIndex],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  final UserRole userRole;
  final String staffId;
  final String userName;
  final VoidCallback? onPhotoChanged;

  const DashboardHome({super.key, required this.userRole, required this.staffId, required this.userName, this.onPhotoChanged});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  int _notificationCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<QuerySnapshot>? _notifSub;
  String? _photoBase64;

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _activity = [];
  int _pendingApprovals = 0;
  int? _liveActiveUsers;
  socket_io.Socket? _socket;
  StreamSubscription<QuerySnapshot>? _approvalsSub;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
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

    _loadDashboardData();

    // Live count of pending account-deletion requests (Firestore is the
    // source of truth for these, not Postgres) — a real snapshots()
    // listener rather than a one-time fetch, so it updates the moment a
    // request is filed or resolved elsewhere.
    _approvalsSub = FirebaseFirestore.instance
        .collection('account_deletion_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() => _pendingApprovals = snapshot.docs.length);
    }, onError: (_) {});

    _socket = socket_io.io(
      WebApiService.apiOrigin,
      socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket!.onConnect((_) {
      _socket!.emit('register', {
        'userId': widget.staffId,
        'role': widget.userRole.name,
        'name': widget.userName,
      });
    });
    _socket!.on('queue_update', (_) => _loadDashboardData());
    _socket!.on('appointment_update', (_) => _loadDashboardData());
    _socket!.on('service_completed', (_) => _loadDashboardData());
    _socket!.on('document_update', (_) => _loadDashboardData());
    _socket!.on('feedback_update', (_) => _loadDashboardData());
    // Fires on every audited action server-side (login, user management,
    // office settings, etc.) — the catch-all for anything the domain-
    // specific listeners above don't already cover.
    _socket!.on('activity_logged', (_) => _loadDashboardData());
    _socket!.on('active_users_changed', (data) {
      if (!mounted) return;
      final count = (data as Map)['count'] as int?;
      if (count != null) setState(() => _liveActiveUsers = count);
    });
    // Security Settings → "Limit Concurrent Sessions": the server evicts
    // this session's socket when a newer login exceeds the configured max.
    _socket!.on('session_kicked', (_) async {
      await WebSession.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WebLogin()),
        (route) => false,
      );
    });
    _socket!.connect();
  }

  Future<void> _loadPhoto() async {
    final id = int.tryParse(widget.staffId);
    if (id == null) return;
    final users = await WebApiService.getUsers();
    final match = users.firstWhere((u) => u['id'] == id, orElse: () => {});
    if (!mounted || match.isEmpty) return;
    setState(() => _photoBase64 = match['photo_url'] as String?);
  }

  Future<void> _loadDashboardData() async {
    final stats = await WebApiService.getDashboardStats();
    final activity = await WebApiService.getDashboardActivity();
    if (!mounted) return;
    setState(() {
      if (stats != null) _stats = stats;
      _activity = activity;
    });
  }

  String _statValue(String key, {String suffix = ''}) {
    final v = _stats?[key];
    if (v == null) return '—';
    if (v is num) {
      if (v == v.roundToDouble()) return '${v.toInt()}$suffix';
      return '${v.toStringAsFixed(1)}$suffix';
    }
    return '$v$suffix';
  }

  (String, String, IconData) _activityDisplay(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '';
    final time = _relativeTime((log['created_at'] as String?) != null ? DateTime.tryParse(log['created_at'] as String) : null);
    switch (action) {
      case 'add_queue':
        return ('web_activity_checkin'.tr(), time, Icons.qr_code);
      case 'call_next':
        return ('web_activity_token_called'.tr(), time, Icons.notifications);
      case 'book_appointment':
        return ('web_activity_appointment_booked'.tr(), time, Icons.calendar_today);
      case 'upload_document':
        return ('web_activity_document_uploaded'.tr(), time, Icons.upload_file);
      case 'complete_service':
        return ('web_activity_service_completed'.tr(), time, Icons.check_circle);
      case 'approve_document':
        return ('web_activity_document_approved'.tr(), time, Icons.check_circle);
      case 'reject_document':
        return ('web_activity_document_rejected'.tr(), time, Icons.cancel);
      case 'submit_feedback':
        return ('web_activity_feedback_submitted'.tr(), time, Icons.star);
      case 'login':
        return ('web_activity_staff_login'.tr(), time, Icons.login);
      case 'reassign_counter':
        return ('web_activity_counter_reassigned'.tr(), time, Icons.swap_horiz);
      case 'process_emergency':
        return ('web_activity_emergency_processed'.tr(), time, Icons.warning_rounded);
      case 'add_emergency':
        return ('web_activity_emergency_added'.tr(), time, Icons.priority_high);
      case 'cancel_queue':
        return ('web_activity_queue_cancelled'.tr(), time, Icons.cancel_outlined);
      case 'create_user':
        return ('web_activity_user_created'.tr(), time, Icons.person_add);
      case 'update_user':
        return ('web_activity_user_updated'.tr(), time, Icons.edit);
      case 'delete_user':
        return ('web_activity_user_deleted'.tr(), time, Icons.person_remove);
      case 'update_user_status':
        return ('web_activity_user_status_updated'.tr(), time, Icons.toggle_on);
      case 'change_password':
        return ('web_activity_password_changed'.tr(), time, Icons.lock_reset);
      case 'update_office_settings':
        return ('web_activity_office_settings_updated'.tr(), time, Icons.settings);
      case 'share_document':
        return ('web_activity_document_shared'.tr(), time, Icons.share);
      case 'update_appointment_status':
        return ('web_activity_appointment_status_updated'.tr(), time, Icons.event_available);
      default:
        return (action.isEmpty ? 'web_activity_generic'.tr() : action.replaceAll('_', ' '), time, Icons.info_outline);
    }
  }

  List<Widget> _buildActivityWidgets({required bool withGaps}) {
    if (_activity.isEmpty) {
      return [
        Text('web_no_recent_activity'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ];
    }
    final items = _activity.take(5).map(_activityDisplay).toList();
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0 && withGaps) widgets.add(const SizedBox(height: 8));
      final (title, time, icon) = items[i];
      widgets.add(_buildActivityItem(title, time, icon));
    }
    return widgets;
  }

  List<Widget> _buildQuickStatWidgets() {
    return [
      _buildQuickStat('web_quickstat_todays_checkins'.tr(), _statValue('todaysCheckIns'), Icons.qr_code_scanner, Colors.blue),
      const SizedBox(height: 12),
      _buildQuickStat('web_quickstat_pending_approvals'.tr(), '$_pendingApprovals', Icons.pending, Colors.orange),
      const SizedBox(height: 12),
      _buildQuickStat('web_quickstat_completed_services'.tr(), _statValue('completedServices'), Icons.check_circle, Colors.green),
      const SizedBox(height: 12),
      _buildQuickStat('web_quickstat_active_users'.tr(), _liveActiveUsers != null ? '$_liveActiveUsers' : _statValue('activeUsers'), Icons.people, Colors.purple),
    ];
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _approvalsSub?.cancel();
    _socket?.dispose();
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
      'service': data['service'],
      'office': data['office'],
      'datetime': data['datetime'],
      'token': data['token'],
      'counter': data['counter'],
      'waitTime': data['waitTime'],
      'ahead': data['ahead'],
      'docName': data['docName'],
      'docStatus': data['docStatus'],
      'uploadedBy': data['uploadedBy'],
      'submittedOn': data['submittedOn'],
      'nic': data['nic'] as String?,
    };
  }

  /// Notifies the citizen identified by [nic] via the `notifications`
  /// collection the citizen app's Notifications screen reads live, looking
  /// the uid up through `nic_index` (same lookup login/service-processing use).
  Future<void> _notifyCitizenByNic(String? nic, String title, String message) async {
    if (nic == null || nic.isEmpty) return;
    try {
      final indexDoc = await FirebaseFirestore.instance.collection('nic_index').doc(nic.toUpperCase()).get();
      final uid = indexDoc.data()?['uid'] as String?;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('notifications').add({
        'uid': uid,
        'title': title,
        'message': message,
        'type': 'queue',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _archiveNotification(String id) async {
    await FirebaseFirestore.instance.collection('staff_notifications').doc(id).set({
      'dismissedBy': FieldValue.arrayUnion([widget.staffId]),
    }, SetOptions(merge: true));
  }

  /// Approves or rejects a citizen's priority-queue request: flips
  /// `is_priority` on their queue entry via the backend, tells the citizen
  /// the outcome, and archives the request so it stops showing as pending.
  /// Also records the outcome as `resolution` (approved/rejected) — read by
  /// `emergency_queue_screen.dart`'s "My Requests" tab so it can distinguish
  /// a rejected request from an approved one instead of just "resolved".
  /// Mirrors `web_notifications.dart`'s `_resolvePriorityRequest`.
  Future<void> _resolvePriorityRequest(Map<String, dynamic> notif, bool approve) async {
    final token = notif['token'] as String?;
    if (token != null) {
      await WebApiService.setQueuePriority(token, approve, officerName: widget.staffId);
    }
    await _notifyCitizenByNic(
      notif['nic'] as String?,
      approve ? 'Priority Request Approved' : 'Priority Request Declined',
      approve
          ? 'Your priority queue request for token $token has been approved.'
          : 'Your priority queue request for token $token was not approved.',
    );
    await FirebaseFirestore.instance.collection('staff_notifications').doc(notif['id'] as String).set({
      'resolution': approve ? 'approved' : 'rejected',
    }, SetOptions(merge: true));
    await _archiveNotification(notif['id'] as String);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approve ? 'Priority request approved' : 'Priority request rejected'),
        backgroundColor: approve ? Colors.green : Colors.grey,
      ),
    );
  }

  String _relativeTime(DateTime? time) {
    if (time == null) return '—';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'web_just_now'.tr();
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${'web_min_ago'.tr()}';
    if (diff.inHours < 24) return '${diff.inHours} ${(diff.inHours > 1 ? 'web_hours_ago' : 'web_hour_ago').tr()}';
    if (diff.inDays < 7) return '${diff.inDays} ${(diff.inDays > 1 ? 'web_days_ago' : 'web_day_ago').tr()}';
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
      SnackBar(content: Text('web_all_notifications_marked_read'.tr()), backgroundColor: Colors.green),
    );
  }

  Future<void> _addTestNotification() async {
    await FirebaseFirestore.instance.collection('staff_notifications').add({
      'title': 'web_test_notification_title'.tr(),
      'message': 'web_test_notification_message'.tr(),
      'type': 'system',
      'action': 'View Details',
      'targetRoles': [widget.userRole.name],
      'readBy': <String>[],
      'dismissedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('web_test_notification_sent'.tr()),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
                          Text(
                            'notifications'.tr(),
                            style: const TextStyle(
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
                              child: Text('web_mark_all_read'.tr(),
                                  style: const TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: notificationsCopy.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.notifications_none,
                                      size: 80, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text('web_no_notifications'.tr(),
                                      style: const TextStyle(color: Colors.grey)),
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
                              label: Text('web_send_test_notification'.tr()),
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
                        Text('web_appointment_details'.tr(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        _buildDetailRow('web_detail_service'.tr(), notif['service']),
                        _buildDetailRow('web_detail_office'.tr(), notif['office']),
                        _buildDetailRow('web_detail_datetime'.tr(), notif['datetime']),
                        _buildDetailRow('web_detail_token'.tr(), notif['token']),
                      ],
                      if (notif['type'] == 'queue') ...[
                        Text('web_queue_details'.tr(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        _buildDetailRow('web_detail_token'.tr(), notif['token']),
                        _buildDetailRow('web_detail_counter'.tr(), notif['counter']),
                        _buildDetailRow('web_detail_estimated_wait'.tr(), notif['waitTime']),
                        _buildDetailRow('web_detail_people_ahead'.tr(), notif['ahead']),
                      ],
                      if (notif['type'] == 'document') ...[
                        Text('web_document_details'.tr(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        _buildDetailRow('web_detail_doc_name'.tr(), notif['docName']),
                        _buildDetailRow('web_detail_status'.tr(), notif['docStatus']),
                        _buildDetailRow('web_detail_uploaded_by'.tr(), notif['uploadedBy']),
                        _buildDetailRow('web_detail_submitted_on'.tr(), notif['submittedOn']),
                      ],
                      const SizedBox(height: 24),
                      if (notif['type'] == 'priority_request')
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _resolvePriorityRequest(notif, false);
                                },
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _resolvePriorityRequest(notif, true);
                                },
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              ),
                            ),
                          ],
                        )
                      else
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
                                          WebAppointments(userRole: widget.userRole, staffId: widget.staffId)),
                                );
                              } else if (notif['action'] == 'View Feedback') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => WebFeedbackList(staffName: widget.userName)),
                                );
                              } else if (notif['action'] == 'View Request') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => WebOnlineServiceRequests(
                                          userRole: widget.userRole, staffId: widget.staffId, staffName: widget.userName)),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'web_action_coming_soon'.tr(args: [notif['action']])),
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

  Widget _buildDetailRow(String label, dynamic value) {
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
            child: Text(value == null ? '—' : value.toString(),
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
        title: Text('web_menu_dashboard'.tr()),
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
                  onSelected: (value) async {
                    if (value == 'profile') {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebProfile(
                            userRole: userRole,
                            userName: userName,
                            userEmail: userEmail,
                            staffId: widget.staffId,
                          ),
                        ),
                      );
                      // Photo may have changed on the profile screen — refresh
                      // so the app bar avatar reflects it without a full reload.
                      _loadPhoto();
                      widget.onPhotoChanged?.call();
                    } else if (value == 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebSettings(
                            userRole: userRole,
                            userName: userName,
                            userEmail: userEmail,
                            staffId: widget.staffId,
                          ),
                        ),
                      );
                    } else if (value == 'logout') {
                      await WebSession.clear();
                      if (!context.mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const WebLogin()),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 18),
                          const SizedBox(width: 10),
                          Text('web_my_profile'.tr()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          const Icon(Icons.settings, size: 18),
                          const SizedBox(width: 10),
                          Text('web_settings'.tr()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          const Icon(Icons.logout, size: 18, color: Colors.red),
                          const SizedBox(width: 10),
                          Text('logout'.tr(), style: const TextStyle(color: Colors.red)),
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
                          backgroundImage: (_photoBase64 != null && _photoBase64!.isNotEmpty)
                              ? MemoryImage(base64Decode(_photoBase64!))
                              : null,
                          child: (_photoBase64 != null && _photoBase64!.isNotEmpty)
                              ? null
                              : Text(
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
                            '${'welcome_back_greeting'.tr()} $userName',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'web_dashboard_subtitle'.tr(),
                            style:
                                const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('web_help_support_coming_soon'.tr()),
                              backgroundColor: const Color(0xFF1A56DB)),
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
                        child: _buildStatCard('web_stat_total_services'.tr(), _statValue('totalServices'),
                            Icons.assignment, Colors.blue,
                            onTap: () => _openScreen(WebAppointments(userRole: widget.userRole, staffId: widget.staffId))),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard(
                            'web_stat_active_queues'.tr(), _statValue('activeQueues'), Icons.queue, Colors.green,
                            onTap: () => _openScreen(const WebQueueManagement())),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('web_stat_todays_appointments'.tr(), _statValue('todaysAppointments'),
                            Icons.calendar_today, Colors.orange,
                            onTap: () => _openScreen(WebAppointments(userRole: widget.userRole, staffId: widget.staffId))),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('web_stat_pending_documents'.tr(), _statValue('pendingDocuments'),
                            Icons.description, Colors.red,
                            onTap: () => _openScreen(const WebDocumentManagement())),
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
                        child: _buildStatCard('web_stat_total_citizens'.tr(), _statValue('totalCitizens'),
                            Icons.people, Colors.purple,
                            onTap: () => _openScreen(WebAppointments(userRole: widget.userRole, staffId: widget.staffId))),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('web_stat_services_completed'.tr(), _statValue('completedServices'),
                            Icons.check_circle, Colors.teal,
                            onTap: () => _openScreen(WebAppointments(userRole: widget.userRole, staffId: widget.staffId))),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('web_stat_avg_satisfaction'.tr(), _statValue('avgSatisfaction'),
                            Icons.star, Colors.amber,
                            onTap: () => _openScreen(WebFeedbackList(staffName: widget.userName))),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildStatCard('web_stat_avg_response'.tr(), _statValue('avgResponseMinutes', suffix: 'min'),
                            Icons.timer, Colors.indigo,
                            onTap: () => _openScreen(const WebQueueManagement())),
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
                              Text('web_recent_activity'.tr(),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ..._buildActivityWidgets(withGaps: false),
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
                              Text('web_quick_stats'.tr(),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ..._buildQuickStatWidgets(),
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
                              Text('web_recent_activity'.tr(),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ..._buildActivityWidgets(withGaps: true),
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
                              Text('web_quick_stats'.tr(),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ..._buildQuickStatWidgets(),
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

  void _openScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final card = Container(
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
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      mouseCursor: SystemMouseCursors.click,
      child: card,
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