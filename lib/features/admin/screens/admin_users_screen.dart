import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:agent_app/shared/models/user_model.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportToGoogleSheets(List<UserModel> users) {
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No users available to export.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      // Write Header Row (Tab-separated for direct paste into Google Sheets)
      buffer.writeln('UID\tFull Name\tEmail\tRole\tVerified\tCreated At');
      
      for (final user in users) {
        final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(user.createdAt);
        buffer.writeln(
          '${user.uid}\t'
          '${user.fullName}\t'
          '${user.email}\t'
          '${user.role}\t'
          '${user.isVerified ? "Yes" : "No"}\t'
          '$dateStr'
        );
      }

      Clipboard.setData(ClipboardData(text: buffer.toString()));

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.table_chart_rounded, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Google Sheets Export'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spreadsheet data copied to clipboard!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 12),
              Text(
                'How to use:\n'
                '1. Open Google Sheets (or any spreadsheet tool).\n'
                '2. Select a starting cell (e.g. A1).\n'
                '3. Press Ctrl+V (Cmd+V on Mac) to paste all users in perfect columns.\n'
                '4. Modify fields as needed and save.',
                style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _editUser(UserModel user) {
    String selectedRole = user.role;
    bool isVerified = user.isVerified;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.manage_accounts_rounded, color: Color(0xFF6366F1), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Manage User',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade800, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                ),
                Text(
                  user.email,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 20),
                const Text(
                  'User Role',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRole,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'tenant', child: Text('Tenant')),
                        DropdownMenuItem(value: 'landlord', child: Text('Landlord')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'customer_support', child: Text('Customer Support')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedRole = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KYC Verified',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        Text(
                          'Toggle user verification badge',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: isVerified,
                      activeThumbColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setDialogState(() {
                          isVerified = val;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _firestore.collection('users').doc(user.uid).update({
                    'role': selectedRole,
                    'isVerified': isVerified,
                  });
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update user: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Manage Users',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No users found in database.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          final List<UserModel> allUsers = snapshot.data!.docs.map((doc) {
            return UserModel.fromMap(doc.data() as Map<String, dynamic>);
          }).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final filteredUsers = allUsers.where((user) {
            final name = user.fullName.toLowerCase();
            final email = user.email.toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();

          return Column(
            children: [
              // Search & Export Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.01),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase().trim();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search users by name, email...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Export button
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade100, width: 1.5),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.table_chart_outlined, color: Colors.green, size: 24),
                        tooltip: 'Export to Google Sheets (CSV)',
                        onPressed: () => _exportToGoogleSheets(filteredUsers),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${filteredUsers.length} of ${allUsers.length} Users',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Text(
                      'Tap card to update user details',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Users List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];

                    // Set colors for roles
                    Color roleColor = Colors.blue;
                    String roleTitle = user.role.toUpperCase();
                    if (user.role == 'admin') {
                      roleColor = Colors.indigo;
                    } else if (user.role == 'landlord') {
                      roleColor = Colors.teal;
                    } else if (user.role == 'customer_support') {
                      roleColor = Colors.purple;
                      roleTitle = 'SUPPORT';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.grey.shade100, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.01),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _editUser(user),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // User Avatar / Initials
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: roleColor.withValues(alpha: 0.1),
                                    child: Text(
                                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                      style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // User Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            // Role Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: roleColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                roleTitle,
                                                style: TextStyle(
                                                  color: roleColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Verified Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: user.isVerified ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                user.isVerified ? 'VERIFIED' : 'UNVERIFIED',
                                                style: TextStyle(
                                                  color: user.isVerified ? Colors.green : Colors.grey.shade600,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Arrow indicator or Edit icon
                                  Icon(Icons.edit_note_rounded, color: Colors.grey.shade300, size: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
