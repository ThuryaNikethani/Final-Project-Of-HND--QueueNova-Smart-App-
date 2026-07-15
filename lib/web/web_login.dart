import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'web_role_model.dart';
import 'web_main.dart';
import 'web_api_service.dart';
import 'web_session.dart';
import '../services/push_notification_service.dart';

class WebLogin extends StatefulWidget {
  const WebLogin({super.key});

  @override
  State<WebLogin> createState() => _WebLoginState();
}

class _WebLoginState extends State<WebLogin> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> _users = [
    {
      'email': 'admin@queuenova.gov.lk',
      'password': 'admin123',
      'role': UserRole.admin,
      'name': 'Admin User'
    },
    {
      'email': 'queue@queuenova.gov.lk',
      'password': 'queue123',
      'role': UserRole.queueManager,
      'name': 'Queue Officer'
    },
    {
      'email': 'service@queuenova.gov.lk',
      'password': 'service123',
      'role': UserRole.serviceProcessor,
      'name': 'Service Officer'
    },
    {
      'email': 'reception@queuenova.gov.lk',
      'password': 'reception123',
      'role': UserRole.reception,
      'name': 'Reception Officer'
    },
    {
      'email': 'manager@queuenova.gov.lk',
      'password': 'manager123',
      'role': UserRole.departmentManager,
      'name': 'Department Manager'
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    _doLogin();
  }

  Future<void> _doLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Try backend API first. A reachable server that rejects these
    // credentials (e.g. a since-changed password) must not fall through to
    // the hardcoded demo list below, or the old password would keep working
    // forever — that fallback is only for when the server can't be reached.
    Map<String, dynamic>? apiUser;
    bool serverReachable = true;
    try {
      apiUser = await WebApiService.login(email, password);
    } catch (e) {
      serverReachable = false;
    }

    if (!mounted) return;

    if (apiUser != null) {
      setState(() => _isLoading = false);
      final role = _roleFromString(apiUser['role'] as String? ?? '');
      final staffId = apiUser['id'];
      if (staffId != null) {
        await PushNotificationService.instance
            .registerToken(collection: 'staff_push_tokens', docId: staffId.toString());
      }
      final resolvedName = apiUser['name'] as String? ?? email;
      final resolvedId = (staffId ?? email).toString();
      await WebSession.save(
        staffId: resolvedId,
        userName: resolvedName,
        userEmail: email,
        userRole: role,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WebDashboard(
            userRole: role,
            userName: resolvedName,
            userEmail: email,
            userId: resolvedId,
          ),
        ),
      );
      return;
    }

    if (serverReachable) {
      // Server was reached and explicitly rejected these credentials —
      // show the real error instead of silently trying the demo list.
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('web_invalid_credentials'.tr()),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Fallback: match against hardcoded list (works without server running)
    final user = _users.firstWhere(
      (u) => u['email'] == email && u['password'] == password,
      orElse: () => {},
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (user.isNotEmpty) {
      await WebSession.save(
        staffId: email,
        userName: user['name'] as String,
        userEmail: email,
        userRole: user['role'] as UserRole,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WebDashboard(
            userRole: user['role'] as UserRole,
            userName: user['name'] as String,
            userEmail: email,
            userId: email,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('web_invalid_credentials'.tr()),
            backgroundColor: Colors.red),
      );
    }
  }

  UserRole _roleFromString(String role) {
    switch (role) {
      case 'Queue Manager':      return UserRole.queueManager;
      case 'Service Officer':    return UserRole.serviceProcessor;
      case 'Reception':          return UserRole.reception;
      case 'Department Manager': return UserRole.departmentManager;
      default:                   return UserRole.admin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A56DB),
              const Color(0xFF0E3A9B),
              Colors.blue.shade800.withOpacity(0.8),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Card(
                      elevation: 20,
                      shadowColor: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      child: Container(
                        width: 480,
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1A56DB),
                                      Color(0xFF7C3AED)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1A56DB)
                                          .withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.speed,
                                      size: 50, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Title
                              const Text(
                                'QueueNova Pulse',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F2937),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'web_login_subtitle'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 36),

                              // REMOVED: Role Selection Dropdown

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                autofillHints: const [],
                                decoration: InputDecoration(
                                  labelText: 'email_address'.tr(),
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: Colors.grey.shade400,
                                  ),
                                  hintText: 'enter_email_hint'.tr(),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1A56DB),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (v) => v!.isEmpty
                                    ? 'web_login_email_required'.tr()
                                    : null,
                              ),
                              const SizedBox(height: 18),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                autofillHints: const [],
                                decoration: InputDecoration(
                                  labelText: 'password'.tr(),
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey.shade400,
                                  ),
                                  suffixIcon: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.grey.shade600,
                                      ),
                                      onPressed: () {
                                        setState(() => _obscurePassword =
                                            !_obscurePassword);
                                      },
                                    ),
                                  ),
                                  hintText: 'web_enter_password_hint'.tr(),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1A56DB),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (v) => v!.isEmpty
                                    ? 'web_login_password_required'.tr()
                                    : null,
                              ),
                              const SizedBox(height: 28),

                              // Sign In Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isLoading
                                        ? Colors.grey.shade400
                                        : const Color(0xFF1A56DB),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'sign_in'.tr(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Footer Text
                              Text(
                                'web_secure_platform_footer'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}