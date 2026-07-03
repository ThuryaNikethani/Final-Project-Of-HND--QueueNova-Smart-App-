import 'package:flutter/material.dart';
import 'web_api_service.dart';

class WebUsersManagement extends StatefulWidget {
  const WebUsersManagement({super.key});

  @override
  State<WebUsersManagement> createState() => _WebUsersManagementState();
}

class _WebUsersManagementState extends State<WebUsersManagement> {
  List<Map<String, dynamic>> users = [
    {
      'name': 'Admin User',
      'email': 'admin@queuenova.gov.lk',
      'role': 'Administrator',
      'status': 'Active',
      'lastActive': 'Just now',
      'avatar': 'AU'
    },
    {
      'name': 'Sarah Johnson',
      'email': 'queue@queuenova.gov.lk',
      'role': 'Queue Manager',
      'status': 'Active',
      'lastActive': '5 min ago',
      'avatar': 'SJ'
    },
    {
      'name': 'Michael Chen',
      'email': 'service@queuenova.gov.lk',
      'role': 'Service Officer',
      'status': 'Active',
      'lastActive': '15 min ago',
      'avatar': 'MC'
    },
    {
      'name': 'Priya Sharma',
      'email': 'reception@queuenova.gov.lk',
      'role': 'Reception',
      'status': 'Offline',
      'lastActive': '2 hours ago',
      'avatar': 'PS'
    },
    {
      'name': 'David Kim',
      'email': 'manager@queuenova.gov.lk',
      'role': 'Department Manager',
      'status': 'Active',
      'lastActive': '30 min ago',
      'avatar': 'DK'
    },
  ];

  final List<String> roles = [
    'Administrator',
    'Queue Manager',
    'Service Officer',
    'Reception',
    'Department Manager'
  ];

  @override
  void initState() {
    super.initState();
    _loadUsersFromApi();
  }

  Future<void> _loadUsersFromApi() async {
    final apiUsers = await WebApiService.getUsers();
    if (!mounted || apiUsers.isEmpty) return;
    setState(() {
      users = apiUsers.map((u) => {
        'id': u['id'],
        'name': u['name'] ?? '',
        'email': u['email'] ?? '',
        'role': u['role'] ?? '',
        'status': u['status'] ?? 'Active',
        'lastActive': _formatLastActive(u['last_active'] as String?),
        'avatar': _initials(u['name'] as String? ?? ''),
      }).toList();
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, 2).toUpperCase() : 'NU';
  }

  String _formatLastActive(String? iso) {
    if (iso == null) return 'Unknown';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'Queue Manager';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New User'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.work),
                ),
                items: roles.map((role) {
                  return DropdownMenuItem(value: role, child: Text(role));
                }).toList(),
                onChanged: (value) => selectedRole = value!,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Temporary Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final password = passwordController.text.isNotEmpty
                  ? passwordController.text
                  : 'changeme123';

              // Optimistic UI update
              final newEntry = {
                'name': name,
                'email': email,
                'role': selectedRole,
                'status': 'Active',
                'lastActive': 'Just now',
                'avatar': _initials(name),
              };
              if (mounted) setState(() => users.add(newEntry));
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User added successfully'), backgroundColor: Colors.green),
                );
              }

              // Persist to backend
              final result = await WebApiService.createUser(
                name: name, email: email, password: password, role: selectedRole,
              );
              if (result != null && result['user'] != null) {
                final u = result['user'] as Map<String, dynamic>;
                if (mounted) {
                  setState(() {
                    final idx = users.indexWhere((x) => x['email'] == email);
                    if (idx != -1) users[idx]['id'] = u['id'];
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: const Text('Add User'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);
    String selectedRole = user['role'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit User'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.work),
                ),
                items: roles.map((role) {
                  return DropdownMenuItem(value: role, child: Text(role));
                }).toList(),
                onChanged: (value) => selectedRole = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();

              // Optimistic UI update
              if (mounted) {
                setState(() {
                  user['name'] = name;
                  user['email'] = email;
                  user['role'] = selectedRole;
                });
              }
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User updated successfully'), backgroundColor: Colors.green),
                );
              }

              // Persist to backend
              final id = user['id'];
              if (id != null) {
                await WebApiService.updateUser(
                  id: id is int ? id : int.tryParse(id.toString()) ?? 0,
                  name: name, email: email, role: selectedRole,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB)),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Optimistic UI removal
              if (mounted) setState(() => users.remove(user));
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User deleted successfully'), backgroundColor: Colors.red),
                );
              }

              // Persist to backend
              final id = user['id'];
              if (id != null) {
                await WebApiService.deleteUser(
                  id is int ? id : int.tryParse(id.toString()) ?? 0,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 30,
              columns: const [
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Last Active')),
                DataColumn(label: Text('Actions')),
              ],
              rows: users.map((user) {
                final isActive = user['status'] == 'Active';
                return DataRow(cells: [
                  DataCell(Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            const Color(0xFF1A56DB).withOpacity(0.1),
                        child: Text(user['avatar'],
                            style: const TextStyle(color: Color(0xFF1A56DB))),
                      ),
                      const SizedBox(width: 12),
                      Text(user['name']),
                    ],
                  )),
                  DataCell(Text(user['email'])),
                  DataCell(Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(user['role'],
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF1A56DB))),
                  )),
                  DataCell(Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isActive ? Colors.green : Colors.red)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user['status'],
                      style: TextStyle(
                          color: isActive ? Colors.green : Colors.red),
                    ),
                  )),
                  DataCell(Text(user['lastActive'])),
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showEditUserDialog(user),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        onPressed: () => _deleteUser(user),
                        tooltip: 'Delete',
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
