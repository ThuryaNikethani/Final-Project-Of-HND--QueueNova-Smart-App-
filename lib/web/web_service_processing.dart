import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebServiceProcessing extends StatefulWidget {
  const WebServiceProcessing({super.key});

  @override
  State<WebServiceProcessing> createState() => _WebServiceProcessingState();
}

class _WebServiceProcessingState extends State<WebServiceProcessing> {
  String selectedFilter = 'Pending';
  final List<String> filters = ['Pending', 'Processing', 'Approved', 'Rejected', 'All'];
  int pendingCount = 0;

  List<Map<String, dynamic>> requests = [
    {
      'id': 'REQ001',
      'citizen': 'K.N.T. Nikethani',
      'nic': '200486403960',
      'service': 'Passport Renewal',
      'date': '25 May 2026',
      'status': 'Pending',
      'paymentStatus': 'paid',
      'fee': 5000,
      'documents': ['NIC Copy', 'Old Passport', 'Photos'],
      'docUrls': ['nic.pdf', 'passport.pdf', 'photo.jpg'],
      'comments': '',
      'processedBy': '',
      'processedAt': '',
    },
    {
      'id': 'REQ002',
      'citizen': 'Saman Perera',
      'nic': '855420159V',
      'service': 'NIC Card',
      'date': '26 May 2026',
      'status': 'Processing',
      'paymentStatus': 'paid',
      'fee': 500,
      'documents': ['Birth Certificate', 'Application Form'],
      'docUrls': ['birth.pdf', 'form.pdf'],
      'comments': '',
      'processedBy': 'Queue Officer',
      'processedAt': '26 May 2026, 10:30 AM',
    },
    {
      'id': 'REQ003',
      'citizen': 'Mala Kumari',
      'nic': '925230080V',
      'service': 'Driving License',
      'date': '27 May 2026',
      'status': 'Pending',
      'paymentStatus': 'pending',
      'fee': 3000,
      'documents': ['NIC Copy', 'Medical Report', 'Test Results'],
      'docUrls': ['nic.pdf', 'medical.pdf', 'test.pdf'],
      'comments': '',
      'processedBy': '',
      'processedAt': '',
    },
    {
      'id': 'REQ004',
      'citizen': 'Ruwan Jaya',
      'nic': '1987456321',
      'service': 'Birth Certificate',
      'date': '28 May 2026',
      'status': 'Approved',
      'paymentStatus': 'paid',
      'fee': 200,
      'documents': ['Hospital Records', 'NIC Copy'],
      'docUrls': ['hospital.pdf', 'nic.pdf'],
      'comments': 'Documents verified successfully',
      'processedBy': 'Service Officer',
      'processedAt': '28 May 2026, 09:15 AM',
    },
    {
      'id': 'REQ005',
      'citizen': 'Nimal Silva',
      'nic': '1978123456',
      'service': 'Police Clearance',
      'date': '29 May 2026',
      'status': 'Rejected',
      'paymentStatus': 'pending',
      'fee': 1000,
      'documents': ['Police Report', 'NIC Copy'],
      'docUrls': ['report.pdf', 'nic.pdf'],
      'comments': 'Incomplete documents. Please submit original police report.',
      'processedBy': 'Service Officer',
      'processedAt': '29 May 2026, 11:00 AM',
    },
  ];

  @override
  void initState() {
    super.initState();
    _updatePendingCount();
  }

  void _updatePendingCount() {
    pendingCount = requests.where((r) => r['status'] == 'Pending').length;
  }

  List<Map<String, dynamic>> get filteredRequests {
    if (selectedFilter == 'All') {
      return requests;
    }
    return requests.where((r) => r['status'] == selectedFilter).toList();
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Processing': return Colors.blue;
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color getPaymentColor(String paymentStatus) {
    return paymentStatus == 'paid' ? Colors.green : Colors.orange;
  }

  void _showDocumentViewer(Map<String, dynamic> request, String docName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Document: $docName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 20),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Document preview will appear here'),
                      Text('Click download to save the file', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareDialog(Map<String, dynamic> request) {
    final List<String> departments = [
      'RMV - Werahera',
      'Divisional Secretariat - Colombo',
      'Passport Office - Battaramulla',
      'Department of Registration',
      'NIC Service Center',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Share this request\'s documents with other departments:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ...departments.map((dept) => ListTile(
              leading: const Icon(Icons.business, color: Color(0xFF1A56DB)),
              title: Text(dept),
              trailing: const Icon(Icons.share),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Documents shared with $dept'), backgroundColor: Colors.green),
                );
              },
            )),
          ],
        ),
      ),
    );
  }

  /// Notifies the citizen identified by [nic] via the `notifications`
  /// collection (the same one the citizen app's Notifications screen reads
  /// live). Looks the uid up through `nic_index`, same as login does.
  Future<void> _notifyCitizenByNic({
    required String? nic,
    required String title,
    required String message,
  }) async {
    if (nic == null || nic.isEmpty) return;
    try {
      final indexDoc = await FirebaseFirestore.instance.collection('nic_index').doc(nic.toUpperCase()).get();
      final uid = indexDoc.data()?['uid'] as String?;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('notifications').add({
        'uid': uid,
        'title': title,
        'message': message,
        'type': 'appointment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('_notifyCitizenByNic error: $e');
    }
  }

  void _showRejectDialog(Map<String, dynamic> request) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                request['status'] = 'Rejected';
                request['comments'] = reasonController.text;
                request['processedBy'] = 'Service Officer';
                request['processedAt'] = _getCurrentDateTime();
              });
              _updatePendingCount();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application rejected'), backgroundColor: Colors.red),
              );
              _notifyCitizenByNic(
                nic: request['nic'] as String?,
                title: 'Application Rejected',
                message: 'Your ${request['service']} application has been rejected. Reason: ${reasonController.text}',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> request) {
    if (request['paymentStatus'] == 'pending') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Payment Required'),
          content: Text('Payment of Rs. ${request['fee']} is pending. Please confirm payment before approving.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Application'),
        content: const Text('Are you sure you want to approve this application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                request['status'] = 'Approved';
                request['comments'] = 'Application approved successfully';
                request['processedBy'] = 'Service Officer';
                request['processedAt'] = _getCurrentDateTime();
              });
              _updatePendingCount();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application approved'), backgroundColor: Colors.green),
              );
              _notifyCitizenByNic(
                nic: request['nic'] as String?,
                title: 'Application Approved',
                message: 'Your ${request['service']} application has been approved.',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}, ${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = filteredRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Processing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 20),
              child: Stack(
                children: [
                  const Icon(Icons.notifications_none, size: 24),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatCard('Pending', requests.where((r) => r['status'] == 'Pending').length.toString(), Colors.orange),
                const SizedBox(width: 16),
                _buildStatCard('Processing', requests.where((r) => r['status'] == 'Processing').length.toString(), Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard('Approved', requests.where((r) => r['status'] == 'Approved').length.toString(), Colors.green),
                const SizedBox(width: 16),
                _buildStatCard('Rejected', requests.where((r) => r['status'] == 'Rejected').length.toString(), Colors.red),
                const SizedBox(width: 16),
                _buildStatCard('Pending Payments', requests.where((r) => r['paymentStatus'] == 'pending').length.toString(), Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 45,
              margin: const EdgeInsets.only(bottom: 20),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final isSelected = selectedFilter == filter;
                  return FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) => setState(() => selectedFilter = filter),
                    selectedColor: const Color(0xFF1A56DB),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final request = filteredList[index];
                  final statusColor = getStatusColor(request['status']);
                  final paymentColor = getPaymentColor(request['paymentStatus']);
                  
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.request_page, color: statusColor),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request['service'],
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Request ID: ${request['id']}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: paymentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        request['paymentStatus'] == 'paid' ? Icons.check_circle : Icons.pending,
                                        size: 14,
                                        color: paymentColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        request['paymentStatus'] == 'paid' ? 'Paid' : 'Payment Pending',
                                        style: TextStyle(fontSize: 12, color: paymentColor, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    request['status'],
                                    style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildInfoRow('Citizen Name', request['citizen'])),
                            Expanded(child: _buildInfoRow('NIC Number', request['nic'])),
                            Expanded(child: _buildInfoRow('Request Date', request['date'])),
                            Expanded(child: _buildInfoRow('Fee', 'Rs. ${request['fee']}')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDocumentsSection(request),
                        const SizedBox(height: 16),
                        if (request['processedBy'].isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.history, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('Processed by: ${request['processedBy']}'),
                                const SizedBox(width: 16),
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('Processed at: ${request['processedAt']}'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (request['comments'].isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.comment, size: 16, color: statusColor),
                                const SizedBox(width: 8),
                                Expanded(child: Text(request['comments'], style: TextStyle(color: statusColor))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (request['status'] == 'Pending' || request['status'] == 'Processing')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showShareDialog(request),
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue)),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => _showRejectDialog(request),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showApproveDialog(request),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDocumentsSection(Map<String, dynamic> request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Uploaded Documents', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(request['documents'].length, (index) {
            final docName = request['documents'][index];
            return GestureDetector(
              onTap: () => _showDocumentViewer(request, docName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file, size: 14, color: Color(0xFF1A56DB)),
                    const SizedBox(width: 4),
                    Text(docName, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.visibility, size: 14, color: Color(0xFF1A56DB)),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}