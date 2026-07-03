import 'package:flutter/material.dart';

class WebNotifications extends StatelessWidget {
  final Map<String, dynamic>? notification;
  final List<Map<String, dynamic>> allNotifications;

  const WebNotifications({
    super.key,
    this.notification,
    required this.allNotifications,
  });

  @override
  Widget build(BuildContext context) {
    // If a specific notification is passed, show details
    if (notification != null) {
      return _buildNotificationDetail(context, notification!);
    }
    // Otherwise show all notifications list
    return _buildNotificationsList(context);
  }

  Widget _buildNotificationsList(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: allNotifications.isEmpty
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
              itemCount: allNotifications.length,
              itemBuilder: (context, index) {
                final notif = allNotifications[index];
                final isRead = notif['read'] as bool;
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WebNotifications(
                          notification: notif,
                          allNotifications: allNotifications,
                        ),
                      ),
                    );
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
                            color: _getNotificationColor(notif['type']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getNotificationIcon(notif['type']),
                            color: _getNotificationColor(notif['type']),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif['title'],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
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
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNotificationDetail(BuildContext context, Map<String, dynamic> notif) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getNotificationColor(notif['type']).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getNotificationIcon(notif['type']),
                color: _getNotificationColor(notif['type']),
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              notif['title'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                notif['time'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Message
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                notif['message'],
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Additional Details based on notification type
            if (notif['type'] == 'appointment')
              _buildAppointmentDetails(notif),
            if (notif['type'] == 'queue')
              _buildQueueDetails(notif),
            if (notif['type'] == 'document')
              _buildDocumentDetails(notif),
            const SizedBox(height: 24),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notification archived'), backgroundColor: Colors.blue),
                      );
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
                      // Handle action based on notification type
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening ${notif['action']}...'), backgroundColor: const Color(0xFF1A56DB)),
                      );
                    },
                    icon: Icon(_getActionIcon(notif['action'])),
                    label: Text(notif['action']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A56DB),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentDetails(Map<String, dynamic> notif) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A56DB).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointment Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Service', notif['service'] ?? 'Passport Renewal'),
          const SizedBox(height: 8),
          _buildDetailRow('Office', notif['office'] ?? 'Divisional Secretariat - Colombo'),
          const SizedBox(height: 8),
          _buildDetailRow('Date & Time', notif['datetime'] ?? '25 May 2026, 10:30 AM'),
          const SizedBox(height: 8),
          _buildDetailRow('Token', notif['token'] ?? 'A-024'),
        ],
      ),
    );
  }

  Widget _buildQueueDetails(Map<String, dynamic> notif) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A56DB).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Queue Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Token', notif['token'] ?? 'A-024'),
          const SizedBox(height: 8),
          _buildDetailRow('Counter', notif['counter'] ?? 'Counter 3'),
          const SizedBox(height: 8),
          _buildDetailRow('Estimated Wait', notif['waitTime'] ?? '5 minutes'),
          const SizedBox(height: 8),
          _buildDetailRow('People Ahead', notif['ahead'] ?? '2 people'),
        ],
      ),
    );
  }

  Widget _buildDocumentDetails(Map<String, dynamic> notif) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A56DB).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Document Name', notif['docName'] ?? 'NIC Copy.pdf'),
          const SizedBox(height: 8),
          _buildDetailRow('Status', notif['docStatus'] ?? 'Under Review'),
          const SizedBox(height: 8),
          _buildDetailRow('Uploaded By', notif['uploadedBy'] ?? 'Citizen'),
          const SizedBox(height: 8),
          _buildDetailRow('Submitted On', notif['submittedOn'] ?? '24 May 2026'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
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