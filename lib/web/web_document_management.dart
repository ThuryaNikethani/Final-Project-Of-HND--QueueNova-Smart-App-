import 'package:flutter/material.dart';

class WebDocumentManagement extends StatefulWidget {
  const WebDocumentManagement({super.key});

  @override
  State<WebDocumentManagement> createState() => _WebDocumentManagementState();
}

class _WebDocumentManagementState extends State<WebDocumentManagement> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Pending', 'Approved', 'Rejected', 'Shared'];

  List<Map<String, dynamic>> documents = [
    {
      'name': 'K.N.T. Nikethani',
      'nic': '200486403960',
      'docType': 'NIC',
      'date': '25 May 2026',
      'status': 'Approved',
      'file': 'nic_copy.pdf',
      'sharedWith': [],
      'sharedCount': 0,
      'rejectionReason': null,
      'reviewedBy': 'Admin User',
      'reviewedAt': '25 May 2026, 10:30 AM',
    },
    {
      'name': 'Saman Perera',
      'nic': '855420159V',
      'docType': 'Passport',
      'date': '24 May 2026',
      'status': 'Approved',
      'file': 'passport.pdf',
      'sharedWith': ['RMV - Werahera'],
      'sharedCount': 1,
      'rejectionReason': null,
      'reviewedBy': 'Queue Officer',
      'reviewedAt': '24 May 2026, 02:15 PM',
    },
    {
      'name': 'Mala Kumari',
      'nic': '925230080V',
      'docType': 'Driving License',
      'date': '23 May 2026',
      'status': 'Pending',
      'file': 'license.pdf',
      'sharedWith': [],
      'sharedCount': 0,
      'rejectionReason': null,
      'reviewedBy': null,
      'reviewedAt': null,
    },
    {
      'name': 'Ruwan Jaya',
      'nic': '1987456321',
      'docType': 'Birth Certificate',
      'date': '22 May 2026',
      'status': 'Approved',
      'file': 'birth.pdf',
      'sharedWith': ['Divisional Secretariat - Colombo', 'Department of Registration'],
      'sharedCount': 2,
      'rejectionReason': null,
      'reviewedBy': 'Admin User',
      'reviewedAt': '22 May 2026, 09:45 AM',
    },
    {
      'name': 'Nimal Silva',
      'nic': '1978123456',
      'docType': 'Police Clearance',
      'date': '21 May 2026',
      'status': 'Rejected',
      'file': 'police.pdf',
      'sharedWith': [],
      'sharedCount': 0,
      'rejectionReason': 'Document is blurry and unreadable. Please upload a clear copy.',
      'reviewedBy': 'Service Officer',
      'reviewedAt': '21 May 2026, 04:20 PM',
    },
  ];

  final List<Map<String, dynamic>> departments = [
    {'name': 'RMV - Werahera', 'icon': Icons.directions_car, 'color': const Color(0xFF1A56DB)},
    {'name': 'Divisional Secretariat - Colombo', 'icon': Icons.business, 'color': const Color(0xFF10B981)},
    {'name': 'Passport Office - Battaramulla', 'icon': Icons.airplane_ticket, 'color': const Color(0xFFF59E0B)},
    {'name': 'Department of Registration', 'icon': Icons.assignment, 'color': const Color(0xFF8B5CF6)},
    {'name': 'NIC Service Center', 'icon': Icons.badge, 'color': const Color(0xFF06B6D4)},
    {'name': 'Immigration Department', 'icon': Icons.book, 'color': const Color(0xFFEF4444)},
    {'name': 'Municipal Council', 'icon': Icons.location_city, 'color': const Color(0xFF6B7280)},
  ];

  // ==================== APPROVAL/REJECTION METHODS ====================

  void _approveDocument(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Document: ${doc['file']}'),
            const SizedBox(height: 8),
            Text('Citizen: ${doc['name']}'),
            const SizedBox(height: 8),
            Text('Type: ${doc['docType']}'),
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
                doc['status'] = 'Approved';
                doc['reviewedBy'] = 'Current Officer';
                doc['reviewedAt'] = DateTime.now().toString().substring(0, 16);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Document approved successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _rejectDocument(Map<String, dynamic> doc) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Document: ${doc['file']}'),
            const SizedBox(height: 8),
            Text('Citizen: ${doc['name']}'),
            const SizedBox(height: 12),
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
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
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for rejection'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              setState(() {
                doc['status'] = 'Rejected';
                doc['rejectionReason'] = reasonController.text.trim();
                doc['reviewedBy'] = 'Current Officer';
                doc['reviewedAt'] = DateTime.now().toString().substring(0, 16);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Document rejected'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showRejectionReason(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: Text(doc['rejectionReason'] ?? 'No reason provided'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(Map<String, dynamic> doc) {
    List<String> tempSelectedDepartments = List.from(doc['sharedWith']);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A56DB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.share, color: Color(0xFF1A56DB)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cross-Department Sharing',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Document: ${doc['file']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Citizen: ${doc['name']} (${doc['nic']})', style: const TextStyle(fontSize: 12)),
                        Text('Document Type: ${doc['docType']}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: doc['status'] == 'Approved' ? Colors.green.withOpacity(0.1) : 
                                    doc['status'] == 'Rejected' ? Colors.red.withOpacity(0.1) : 
                                    Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Status: ${doc['status']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: doc['status'] == 'Approved' ? Colors.green : 
                                     doc['status'] == 'Rejected' ? Colors.red : 
                                     Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Share with Departments:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select departments that need access to this document',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: departments.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final dept = departments[index];
                        final isSelected = tempSelectedDepartments.contains(dept['name']);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (bool? checked) {
                            setModalState(() {
                              if (checked == true) {
                                tempSelectedDepartments.add(dept['name']);
                              } else {
                                tempSelectedDepartments.remove(dept['name']);
                              }
                            });
                          },
                          title: Text(dept['name']),
                          secondary: Icon(dept['icon'], color: dept['color']),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: const Color(0xFF1A56DB),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF1A56DB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Shared documents will be accessible to officers in selected departments.',
                            style: TextStyle(fontSize: 11, color: const Color(0xFF1A56DB)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              doc['sharedWith'] = tempSelectedDepartments;
                              doc['sharedCount'] = tempSelectedDepartments.length;
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Document shared with ${tempSelectedDepartments.length} department(s)'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56DB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Share Document'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocs = selectedFilter == 'All' 
        ? documents 
        : selectedFilter == 'Shared'
            ? documents.where((d) => d['sharedCount'] > 0).toList()
            : documents.where((d) => d['status'] == selectedFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Document Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Stats Cards
            Row(
              children: [
                _buildStatCard('Total Documents', documents.length.toString(), Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('Pending', 
                    documents.where((d) => d['status'] == 'Pending').length.toString(), 
                    Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard('Approved', 
                    documents.where((d) => d['status'] == 'Approved').length.toString(), 
                    Colors.green),
                const SizedBox(width: 12),
                _buildStatCard('Rejected', 
                    documents.where((d) => d['status'] == 'Rejected').length.toString(), 
                    Colors.red),
                const SizedBox(width: 12),
                _buildStatCard('Shared', 
                    documents.where((d) => d['sharedCount'] > 0).length.toString(), 
                    const Color(0xFF1A56DB)),
              ],
            ),
            const SizedBox(height: 20),
            // Filter Chips
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
            // Documents Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columnSpacing: 16,
                      dataRowHeight: 60,
                      columns: const [
                        DataColumn(label: Text('Citizen Name', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('NIC', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Document Type', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Upload Date', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Shared With', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                      ],
                      rows: filteredDocs.map((doc) {
                        Color statusColor = doc['status'] == 'Approved' 
                            ? Colors.green 
                            : (doc['status'] == 'Pending' ? Colors.orange : Colors.red);
                        return DataRow(cells: [
                          DataCell(Text(doc['name'])),
                          DataCell(Text(doc['nic'])),
                          DataCell(Text(doc['docType'])),
                          DataCell(Text(doc['date'])),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    doc['status'] == 'Approved' ? Icons.check_circle : 
                                    (doc['status'] == 'Pending' ? Icons.pending : Icons.cancel),
                                    size: 14,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(doc['status'], 
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            doc['sharedCount'] == 0
                                ? const Text('Not shared', style: TextStyle(color: Colors.grey))
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A56DB).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${doc['sharedCount']} dept(s)',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF1A56DB)),
                                    ),
                                  ),
                          ),
                          DataCell(
                            Wrap(
                              spacing: 4,
                              children: [
                                // View Document
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 18, color: Colors.blue),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Viewing document - Coming Soon')),
                                    );
                                  },
                                  tooltip: 'View Document',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                // Approve Button (only for pending)
                                if (doc['status'] == 'Pending') ...[
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                                    onPressed: () => _approveDocument(doc),
                                    tooltip: 'Approve',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                    onPressed: () => _rejectDocument(doc),
                                    tooltip: 'Reject',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                                // Rejection Reason (only for rejected)
                                if (doc['status'] == 'Rejected' && doc['rejectionReason'] != null)
                                  IconButton(
                                    icon: const Icon(Icons.info_outline, size: 18, color: Colors.red),
                                    onPressed: () => _showRejectionReason(doc),
                                    tooltip: 'View Rejection Reason',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                // Share Button
                                IconButton(
                                  icon: const Icon(Icons.share, size: 18, color: Color(0xFF1A56DB)),
                                  onPressed: () => _showShareDialog(doc),
                                  tooltip: 'Cross-Department Sharing',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
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

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}