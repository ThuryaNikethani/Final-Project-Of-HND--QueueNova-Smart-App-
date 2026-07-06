import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:queuenova_mobile/config/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Unread', 'Queue', 'Appointment', 'System'];

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> notifications = [];
  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _loading = false;
      return;
    }
    // Sorted client-side (rather than orderBy in the query) to avoid needing
    // a Firestore composite index just for this lookup.
    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        notifications = snapshot.docs.map((d) {
          final data = d.data();
          final type = data['type'] as String? ?? 'system';
          final createdAt = data['createdAt'] as Timestamp?;
          return {
            'id': d.id,
            'title': data['title'] as String? ?? '',
            'message': data['message'] as String? ?? '',
            'type': type,
            'isRead': data['isRead'] as bool? ?? false,
            'timestamp': createdAt?.toDate() ?? DateTime.now(),
            'icon': _iconFor(type),
            'color': _colorFor(type),
          };
        }).toList()
          ..sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
        _loading = false;
        _error = null;
      });
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'queue':
        return Icons.queue_rounded;
      case 'appointment':
        return Icons.calendar_today_rounded;
      case 'account_deletion':
        return Icons.person_remove_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'queue':
        return AppColors.info;
      case 'appointment':
        return AppColors.primaryBlue;
      case 'account_deletion':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  List<Map<String, dynamic>> get filteredNotifications {
    if (selectedFilter == 'All') {
      return notifications;
    } else if (selectedFilter == 'Unread') {
      return notifications.where((n) => n['isRead'] == false).toList();
    } else {
      return notifications.where((n) => n['type'] == selectedFilter.toLowerCase()).toList();
    }
  }

  int get unreadCount {
    return notifications.where((n) => n['isRead'] == false).length;
  }

  void _markAsRead(String id) {
    FirebaseFirestore.instance.collection('notifications').doc(id).update({'isRead': true});
  }

  void _markAllAsRead() {
    final batch = FirebaseFirestore.instance.batch();
    for (final n in notifications.where((n) => n['isRead'] == false)) {
      batch.update(FirebaseFirestore.instance.collection('notifications').doc(n['id'] as String), {'isRead': true});
    }
    batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final batch = FirebaseFirestore.instance.batch();
              for (final n in notifications) {
                batch.delete(FirebaseFirestore.instance.collection('notifications').doc(n['id'] as String));
              }
              await batch.commit();
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications cleared'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('dd MMM yyyy').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = filteredNotifications;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  _markAllAsRead();
                } else if (value == 'clear_all') {
                  _clearAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Mark all as read'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Clear all'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(45),
          child: Container(
            height: 45,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = selectedFilter == filter;
                return FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) => setState(() => selectedFilter = filter),
                  selectedColor: AppColors.primaryBlue,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  backgroundColor: AppColors.offWhite,
                );
              },
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load notifications:\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          : filteredList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 80,
                    color: AppColors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re all caught up!',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.grey.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final notification = filteredList[index];
                final isUnread = notification['isRead'] == false;
                
                return GestureDetector(
                  onTap: () {
                    if (isUnread) {
                      _markAsRead(notification['id']);
                    }
                    _showNotificationDetails(notification);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isUnread ? AppColors.lightBlue : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isUnread ? AppColors.primaryBlue : AppColors.greyLight,
                        width: isUnread ? 1.5 : 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon Container
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (notification['color'] as Color).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  notification['icon'],
                                  color: notification['color'],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification['title'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notification['message'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatTime(notification['timestamp']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Unread indicator
                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryBlue,
                                    shape: BoxShape.circle,
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
            ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.greyLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (notification['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  notification['icon'],
                  color: notification['color'],
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                notification['title'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(notification['timestamp']),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.grey,
                ),
              ),
              const Divider(height: 24),
              Text(
                notification['message'],
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}