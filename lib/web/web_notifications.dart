import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'web_role_model.dart';

/// Persistent, browsable notification history for officers — reads live
/// from the same `staff_notifications` collection the dashboard bell
/// (DashboardHome in web_main.dart) uses, so counts and content always
/// match. Unlike the bell dropdown, this is a full page reachable from the
/// sidebar and keeps showing read notifications until archived.
class WebNotifications extends StatefulWidget {
  final UserRole userRole;
  final String staffId;

  const WebNotifications({
    super.key,
    required this.userRole,
    required this.staffId,
  });

  @override
  State<WebNotifications> createState() => _WebNotificationsState();
}

class _WebNotificationsState extends State<WebNotifications> {
  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    // Sorted client-side (rather than orderBy in the query) to avoid needing
    // a Firestore composite index for an arrayContains + orderBy combination.
    _sub = FirebaseFirestore.instance
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
            .toList();
        _loading = false;
      });
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
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

  Future<void> _archive(String id) async {
    await FirebaseFirestore.instance.collection('staff_notifications').doc(id).set({
      'dismissedBy': FieldValue.arrayUnion([widget.staffId]),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] == false).length;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notification History'),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$unreadCount', style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No notifications', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('You\'re all caught up!', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final isRead = notif['read'] as bool;
                    return GestureDetector(
                      onTap: () {
                        if (!isRead) _markAsRead(notif['id'] as String);
                        _showNotificationDetail(notif);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isRead ? Colors.grey.shade200 : const Color(0xFF1A56DB),
                            width: isRead ? 1 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getNotificationColor(notif['type'] as String).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getNotificationIcon(notif['type'] as String),
                                color: _getNotificationColor(notif['type'] as String),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notif['title'] as String,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notif['message'] as String,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notif['time'] as String,
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showNotificationDetail(Map<String, dynamic> notif) {
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
                  color: _getNotificationColor(notif['type'] as String),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_getNotificationIcon(notif['type'] as String), color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notif['title'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(notif['time'] as String, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(notif['message'] as String, style: const TextStyle(fontSize: 14, height: 1.5)),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _archive(notif['id'] as String);
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.archive),
                              label: const Text('Archive'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${notif['action']} — see the relevant module in the sidebar'),
                                    backgroundColor: const Color(0xFF1A56DB),
                                  ),
                                );
                              },
                              icon: Icon(_getActionIcon(notif['action'] as String)),
                              label: Text(notif['action'] as String),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
                            ),
                          ),
                        ],
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

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'appointment': return Colors.orange;
      case 'queue': return Colors.blue;
      case 'document': return Colors.purple;
      case 'system': return Colors.green;
      default: return const Color(0xFF1A56DB);
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'appointment': return Icons.calendar_today;
      case 'queue': return Icons.queue;
      case 'document': return Icons.description;
      case 'system': return Icons.settings;
      default: return Icons.notifications;
    }
  }

  IconData _getActionIcon(String action) {
    if (action.contains('View')) return Icons.visibility;
    if (action.contains('Check')) return Icons.qr_code_scanner;
    if (action.contains('Approve')) return Icons.check_circle;
    return Icons.arrow_forward;
  }
}
