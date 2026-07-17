import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'web_api_service.dart';

/// Opened by tapping the Dashboard's "Avg. Satisfaction" stat card. Lists
/// every citizen feedback entry (rating + comment) so staff can actually
/// read what citizens wrote — previously only the aggregate average number
/// was visible anywhere. Officers can reply; the reply is persisted and
/// pushed to the citizen instantly via the same Firestore `notifications`
/// collection the citizen app's Notifications screen already reads live.
class WebFeedbackList extends StatefulWidget {
  final String staffName;

  const WebFeedbackList({super.key, required this.staffName});

  @override
  State<WebFeedbackList> createState() => _WebFeedbackListState();
}

class _WebFeedbackListState extends State<WebFeedbackList> {
  bool _loading = true;
  List<Map<String, dynamic>> _feedback = [];
  socket_io.Socket? _socket;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Excellent', 'Good', 'Bad'];

  @override
  void initState() {
    super.initState();
    _load();
    _socket = socket_io.io(
      'http://localhost:3000',
      socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket!.on('feedback_update', (_) => _load());
    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await WebApiService.getFeedbackList();
    if (!mounted) return;
    setState(() {
      _feedback = rows;
      _loading = false;
    });
  }

  // 5 stars = Excellent, 3-4 = Good, 1-2 = Bad.
  String _category(int rating) {
    if (rating >= 5) return 'Excellent';
    if (rating >= 3) return 'Good';
    return 'Bad';
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Excellent': return Colors.green;
      case 'Good': return Colors.blue;
      case 'Bad': return Colors.red;
      default: return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get _filteredFeedback {
    if (_selectedCategory == 'All') return _feedback;
    return _feedback.where((item) {
      final rating = (item['rating'] as num?)?.toInt() ?? 0;
      return _category(rating) == _selectedCategory;
    }).toList();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('d MMM yyyy, hh:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  /// Same lookup the officer dashboard already uses elsewhere
  /// (web_service_processing.dart's `_notifyCitizenByNic`): resolve the
  /// citizen's Firebase uid via `nic_index`, then write a doc into
  /// `notifications`, the collection the citizen app's Notifications screen
  /// listens to live.
  Future<void> _notifyCitizenOfReply({
    required String? nic,
    required String service,
    required String reply,
  }) async {
    if (nic == null || nic.isEmpty) return;
    try {
      final indexDoc = await FirebaseFirestore.instance.collection('nic_index').doc(nic.toUpperCase()).get();
      final uid = indexDoc.data()?['uid'] as String?;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('notifications').add({
        'uid': uid,
        'title': 'Reply to your feedback',
        'message': '$service: $reply',
        'type': 'feedback',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyCitizenOfReply error: $e');
    }
  }

  void _showReplyDialog(Map<String, dynamic> item) {
    final controller = TextEditingController(text: item['reply'] as String? ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reply to Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${item['citizen_name'] ?? ''} — ${item['service'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type your reply...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final reply = controller.text.trim();
              if (reply.isEmpty) return;
              Navigator.pop(context);
              final ok = await WebApiService.replyToFeedback(item['id'] as int, reply, widget.staffName);
              if (ok) {
                await _notifyCitizenOfReply(
                  nic: item['citizen_nic'] as String?,
                  service: (item['service'] as String?) ?? '',
                  reply: reply,
                );
                await _load();
              }
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.red),
                      const SizedBox(width: 10),
                      Text(ok ? 'Reply Sent' : 'Reply Failed'),
                    ],
                  ),
                  content: Text(ok
                      ? 'Your reply has been sent to the citizen instantly.'
                      : 'Failed to send reply. Please try again.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('ok'.tr()),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
            i < rating ? Icons.star : Icons.star_border,
            size: 16,
            color: Colors.amber,
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Citizen Feedback'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  height: 45,
                  margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedCategory = category),
                        selectedColor: const Color(0xFF1A56DB),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _filteredFeedback.isEmpty
                      ? const Center(child: Text('No feedback yet'))
                      : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _filteredFeedback.length,
                  itemBuilder: (context, index) {
                    final item = _filteredFeedback[index];
                    final hasReply = (item['reply'] as String?)?.isNotEmpty == true;
                    final rating = (item['rating'] as num?)?.toInt() ?? 0;
                    final category = _category(rating);
                    final categoryColor = _categoryColor(category);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (item['citizen_name'] as String?)?.isNotEmpty == true
                                        ? item['citizen_name'] as String
                                        : 'Anonymous',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    item['service'] as String? ?? '',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildStars(rating),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: categoryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(fontSize: 11, color: categoryColor, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if ((item['comment'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            Text(item['comment'] as String, style: const TextStyle(fontSize: 14)),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(item['created_at']?.toString()),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 12),
                          if (hasReply)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reply from ${item['replied_by'] ?? 'Officer'}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A56DB)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(item['reply'] as String, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _showReplyDialog(item),
                              icon: Icon(hasReply ? Icons.edit : Icons.reply, size: 16),
                              label: Text(hasReply ? 'Edit Reply' : 'Reply'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                        ),
                ),
              ],
            ),
    );
  }
}
