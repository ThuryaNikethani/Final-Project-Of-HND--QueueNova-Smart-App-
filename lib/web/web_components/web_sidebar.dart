import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../web_role_model.dart';

class WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final UserRole userRole;
  final String userName;
  final String userEmail;
  final List<Map<String, dynamic>> menuItems;

  const WebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.userRole,
    required this.userName,
    required this.userEmail,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = selectedIndex < menuItems.length ? selectedIndex : 0;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Logo Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A56DB), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A56DB).withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.speed, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QueueNova',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Pulse',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Divider(height: 1),
          ),

          // User Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A56DB).withOpacity(0.05),
                    const Color(0xFF7C3AED).withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A56DB), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A56DB).withOpacity(0.25),
                          blurRadius: 12,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: RolePermissions.getRoleColor(userRole)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: RolePermissions.getRoleColor(userRole)
                            .withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      RolePermissions.getRoleName(userRole),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: RolePermissions.getRoleColor(userRole),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Divider(height: 1),
          ),

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isSelected = safeIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? const Color(0xFF1A56DB).withOpacity(0.08)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1A56DB).withOpacity(0.2)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onItemSelected(index),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1A56DB)
                                            .withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    item['icon'],
                                    color: isSelected
                                        ? const Color(0xFF1A56DB)
                                        : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['label'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF1A56DB)
                                          : Colors.grey.shade700,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 13,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                if (item['permission'] == 'account_deletion_requests')
                                  _PendingDeletionBadge(),
                                if (isSelected)
                                  Container(
                                    width: 3,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A56DB),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Divider(height: 1),
          ),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.withOpacity(0.05),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.logout,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 0.2,
                              ),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Live count of pending account-deletion requests, shown as a small red
/// badge next to that sidebar item so officers notice new requests without
/// needing to open the screen or click refresh.
class _PendingDeletionBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('account_deletion_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}