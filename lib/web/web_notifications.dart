import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/services/queue_status_service.dart';
import 'web_role_model.dart';
import 'web_api_service.dart';

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
  bool _backfilling = false;
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
      'token': data['token'] as String?,
      'nic': data['nic'] as String?,
    };
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

  Future<void> _archive(String id) async {
    await FirebaseFirestore.instance.collection('staff_notifications').doc(id).set({
      'dismissedBy': FieldValue.arrayUnion([widget.staffId]),
    }, SetOptions(merge: true));
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

  /// Approves or rejects a citizen's priority-queue request: flips
  /// `is_priority` on their queue entry via the backend, tells the citizen
  /// the outcome, and archives the request so it stops showing as pending.
  /// Also records the outcome as `resolution` (approved/rejected) — read by
  /// `emergency_queue_screen.dart`'s "My Requests" tab so it can distinguish
  /// a rejected request from an approved one instead of just "resolved".
  Future<void> _resolvePriorityRequest(Map<String, dynamic> notif, bool approve) async {
    final token = notif['token'] as String?;
    if (token != null) {
      final error = await WebApiService.setQueuePriority(token, approve, officerName: widget.staffId);
      if (error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
        return;
      }
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
    await _archive(notif['id'] as String);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approve ? 'Priority request approved' : 'Priority request rejected'),
        backgroundColor: approve ? Colors.green : Colors.grey,
      ),
    );
  }

  /// One-time maintenance action: priority requests resolved before the
  /// `resolution` field existed have no recorded approved/rejected outcome,
  /// so the citizen's "My Requests" tab can only show them as generic
  /// "Completed". This finds those old requests and infers the real outcome
  /// from the current `is_priority` value on their queue entry (set at
  /// approval time and never reset), backfilling `resolution` so they display
  /// correctly. Requests whose queue entry no longer exists are left as-is —
  /// there's nothing left to infer the outcome from.
  Future<void> _backfillResolutions() async {
    setState(() => _backfilling = true);
    var updated = 0;
    var skipped = 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('staff_notifications')
          .where('type', isEqualTo: 'priority_request')
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dismissedBy = (data['dismissedBy'] as List?) ?? const [];
        final token = data['token'] as String?;
        if (dismissedBy.isEmpty || data['resolution'] != null || token == null) continue;
        final entry = await QueueStatusService.getQueueEntry(token);
        if (entry['found'] != true) {
          skipped++;
          continue;
        }
        await doc.reference.set({
          'resolution': entry['isPriority'] == true ? 'approved' : 'rejected',
        }, SetOptions(merge: true));
        updated++;
      }
    } catch (_) {
      // Leave whatever was already updated in place; report what happened below.
    }
    if (!mounted) return;
    setState(() => _backfilling = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(skipped > 0
            ? 'Updated $updated old request(s); $skipped could not be determined.'
            : 'Updated $updated old request(s).'),
        backgroundColor: const Color(0xFF1A56DB),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] == false).length;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('web_menu_notification_history'.tr()),
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
          IconButton(
            icon: _backfilling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.history_toggle_off),
            tooltip: 'Fix old priority requests still showing as "Completed"',
            onPressed: _backfilling ? null : _backfillResolutions,
          ),
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text('web_mark_all_read'.tr()),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('web_no_notifications'.tr(), style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('web_all_caught_up'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _archive(notif['id'] as String);
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.archive),
                                label: Text('web_archive_button'.tr()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('web_action_see_sidebar_module'.tr(args: ['${notif['action']}'])),
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
      case 'priority_request': return Colors.deepOrange;
      case 'document': return Colors.purple;
      case 'system': return Colors.green;
      default: return const Color(0xFF1A56DB);
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'appointment': return Icons.calendar_today;
      case 'queue': return Icons.queue;
      case 'priority_request': return Icons.priority_high;
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
