import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/screens/profile_screen.dart';
import 'package:queuenova_mobile/screens/bookings_screen.dart';
import 'package:queuenova_mobile/screens/queue_tab_screen.dart';
import 'package:queuenova_mobile/screens/book_appointment_screen.dart';
import 'package:queuenova_mobile/screens/queue_status_screen.dart';
import 'package:queuenova_mobile/screens/upload_document_screen.dart';
import 'package:queuenova_mobile/screens/request_tracking_screen.dart';
import 'package:queuenova_mobile/screens/qr_checkin_screen.dart';
import 'package:queuenova_mobile/screens/document_vault_screen.dart';
import 'package:queuenova_mobile/screens/smart_office_screen.dart';
import 'package:queuenova_mobile/screens/emergency_queue_screen.dart';
import 'package:queuenova_mobile/screens/services_screen.dart';
import 'package:queuenova_mobile/screens/feedback_screen.dart';
import 'package:queuenova_mobile/screens/notifications_screen.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const BookingsScreen(),
    const QueueTabScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home_rounded), label: 'home'.tr()),
            BottomNavigationBarItem(icon: const Icon(Icons.calendar_today_rounded), label: 'bookings'.tr()),
            BottomNavigationBarItem(icon: const Icon(Icons.queue_rounded), label: 'queue'.tr()),
            BottomNavigationBarItem(icon: const Icon(Icons.person_rounded), label: 'profile'.tr()),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final PageController _pageController = PageController();
  int _currentActionIndex = 0;

  final List<Map<String, dynamic>> quickActions = [
    {'titleKey': 'book_appointment', 'subtitleKey': 'schedule_a_service', 'icon': Icons.calendar_month_rounded, 'color': const Color(0xFF1A56DB), 'screen': const BookAppointmentScreen()},
    {'titleKey': 'queue_status_nav', 'subtitleKey': 'check_your_turn', 'icon': Icons.queue_rounded, 'color': const Color(0xFF10B981), 'screen': const QueueStatusScreen()},
    {'titleKey': 'upload_document', 'subtitleKey': 'submit_files', 'icon': Icons.upload_file_rounded, 'color': const Color(0xFFF59E0B), 'screen': const DocumentUploadScreen()},
    {'titleKey': 'track_request', 'subtitleKey': 'view_progress', 'icon': Icons.track_changes_rounded, 'color': const Color(0xFF8B5CF6), 'screen': const RequestTrackingScreen()},
    {'titleKey': 'my_qr_code', 'subtitleKey': 'for_check_in', 'icon': Icons.qr_code_scanner_rounded, 'color': const Color(0xFF06B6D4), 'screen': const QRCheckInScreen()},
    {'titleKey': 'document_vault', 'subtitleKey': 'your_documents', 'icon': Icons.folder_rounded, 'color': const Color(0xFFEC4899), 'screen': const DocumentVaultScreen()},
    {'titleKey': 'smart_office', 'subtitleKey': 'find_best_office', 'icon': Icons.location_city_rounded, 'color': const Color(0xFF14B8A6), 'screen': const SmartOfficeScreen()},
    {'titleKey': 'emergency_queue', 'subtitleKey': 'priority_help', 'icon': Icons.warning_rounded, 'color': const Color(0xFFEF4444), 'screen': const EmergencyQueueScreen()},
    {'titleKey': 'all_services', 'subtitleKey': 'browse_all', 'icon': Icons.grid_view_rounded, 'color': const Color(0xFF6B7280), 'screen': const ServicesScreen()},
    {'titleKey': 'feedback_action', 'subtitleKey': 'rate_us', 'icon': Icons.rate_review_rounded, 'color': const Color(0xFF1A56DB), 'screen': const FeedbackScreen()},
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern Header
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A56DB),
                      Color(0xFF0E3A9B),
                      Color(0xFF0047AB),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'live'.tr(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'welcome_back_greeting'.tr(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  authService.userName?.split(' ').first ?? 'Citizen',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            // Notifications Button Only (Chat Removed)
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.notifications_none_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const NotificationsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (FirebaseAuth.instance.currentUser != null)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('notifications')
                                          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                                          .where('isRead', isEqualTo: false)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        final count = snapshot.data?.docs.length ?? 0;
                                        if (count == 0) return const SizedBox.shrink();
                                        return Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                          child: Text(
                                            '$count',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.queue_play_next_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'current_token_label'.tr(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'A-024',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      '4',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                    Text(
                                      'ahead'.tr(),
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Service Categories Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final List<Map<String, dynamic>> categories = [
                    {'name': 'passport', 'icon': Icons.airplane_ticket_rounded, 'color': const Color(0xFF1A56DB)},
                    {'name': 'nic_category', 'icon': Icons.badge_rounded, 'color': const Color(0xFF10B981)},
                    {'name': 'driving', 'icon': Icons.directions_car_rounded, 'color': const Color(0xFFF59E0B)},
                    {'name': 'birth', 'icon': Icons.celebration_rounded, 'color': const Color(0xFF8B5CF6)},
                    {'name': 'visa', 'icon': Icons.flight_rounded, 'color': const Color(0xFF06B6D4)},
                    {'name': 'more', 'icon': Icons.more_horiz_rounded, 'color': const Color(0xFF6B7280)},
                  ];
                  final category = categories[index];
                  final Color catColor = category['color'] as Color;
                  final IconData catIcon = category['icon'] as IconData;
                  final String catName = category['name'] as String;
                  
                  return GestureDetector(
                    onTap: () {
                      if (catName == 'more') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ServicesScreen()));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('service_coming_soon'.tr(args: [catName.tr()])),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primaryBlue,
                          ),
                        );
                      }
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [catColor, catColor.withOpacity(0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: catColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(catIcon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          catName.tr(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // Quick Actions
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'quick_actions'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_currentActionIndex > 0) {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.chevron_left, size: 18, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              if (_currentActionIndex < quickActions.length - 1) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Page Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      quickActions.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentActionIndex == index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentActionIndex == index
                              ? AppColors.primaryBlue
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // PageView
                  SizedBox(
                    height: 280,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentActionIndex = index;
                        });
                      },
                      itemCount: quickActions.length,
                      itemBuilder: (context, index) {
                        final action = quickActions[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildLargeActionCard(
                            context,
                            icon: action['icon'] as IconData,
                            title: (action['titleKey'] as String).tr(),
                            subtitle: (action['subtitleKey'] as String).tr(),
                            color: action['color'] as Color,
                            screen: action['screen'] as Widget,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Statistics Row
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(child: _buildStatCard(title: 'stat_services'.tr(), value: '12', change: '+2.5%', icon: Icons.assessment_rounded, gradient: const LinearGradient(colors: [Color(0xFF1A56DB), Color(0xFF0E3A9B)]))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(title: 'avg_wait'.tr(), value: '24m', change: '-8%', icon: Icons.timer_rounded, gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(title: 'rating'.tr(), value: '4.8', change: '+0.3', icon: Icons.star_rounded, gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]))),
                ],
              ),
            ),
          ),
          // Recent Appointments Section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'recent_appointments'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingsScreen()));
                        },
                        child: Text(
                          'see_all'.tr(),
                          style: const TextStyle(color: AppColors.primaryBlue, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAppointmentCard(
                    icon: Icons.airplane_ticket_rounded,
                    title: 'Passport Renewal',
                    office: 'Passport Office - Battaramulla',
                    date: '25 Mar 2026',
                    status: 'pending'.tr(),
                    statusColor: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 8),
                  _buildAppointmentCard(
                    icon: Icons.badge_rounded,
                    title: 'National ID Card',
                    office: 'NIC Service Center - Colombo',
                    date: '28 Mar 2026',
                    status: 'confirmed'.tr(),
                    statusColor: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 8),
                  _buildAppointmentCard(
                    icon: Icons.directions_car_rounded,
                    title: 'Driving License',
                    office: 'RMV - Werahera',
                    date: '20 Mar 2026',
                    status: 'completed_status'.tr(),
                    statusColor: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeActionCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
      child: Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'tap_to_open'.tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A56DB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1A56DB)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String change,
    required IconData icon,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 12),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
              Text(
                change,
                style: const TextStyle(fontSize: 8, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard({
    required IconData icon,
    required String title,
    required String office,
    required String date,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 9, color: Colors.grey.shade500),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        office,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 9, color: Colors.grey.shade500),
                    const SizedBox(width: 2),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}