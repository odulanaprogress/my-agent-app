import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:agent_app/core/widgets/app_loader.dart';

class Customer360Screen extends ConsumerStatefulWidget {
  final String? initialUserId;

  const Customer360Screen({super.key, this.initialUserId});

  @override
  ConsumerState<Customer360Screen> createState() => _Customer360ScreenState();
}

class _Customer360ScreenState extends ConsumerState<Customer360Screen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  String? _currentUserId;
  Map<String, dynamic>? _userData;
  bool _searching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    if (widget.initialUserId != null && widget.initialUserId!.isNotEmpty) {
      _currentUserId = widget.initialUserId;
      _loadCustomerById(widget.initialUserId!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _searchCustomer() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _errorMessage = null;
    });

    try {
      final fs = FirebaseFirestore.instance;

      // 1. Direct UID Document lookup
      final docSnap = await fs.collection('users').doc(query).get();
      if (docSnap.exists) {
        setState(() {
          _currentUserId = docSnap.id;
          _userData = docSnap.data();
          _searching = false;
        });
        return;
      }

      // 2. Email lookup
      final emailSnap = await fs
          .collection('users')
          .where('email', isEqualTo: query.toLowerCase())
          .limit(1)
          .get();
      if (emailSnap.docs.isNotEmpty) {
        setState(() {
          _currentUserId = emailSnap.docs.first.id;
          _userData = emailSnap.docs.first.data();
          _searching = false;
        });
        return;
      }

      // 3. Phone Number lookup
      final phoneSnap = await fs
          .collection('users')
          .where('phone', isEqualTo: query)
          .limit(1)
          .get();
      if (phoneSnap.docs.isNotEmpty) {
        setState(() {
          _currentUserId = phoneSnap.docs.first.id;
          _userData = phoneSnap.docs.first.data();
          _searching = false;
        });
        return;
      }

      // 4. Virtual Account Number lookup (from transactions)
      final vaSnap = await fs
          .collection('transactions')
          .where('virtualAccountNumber', isEqualTo: query)
          .limit(1)
          .get();
      if (vaSnap.docs.isNotEmpty) {
        final uid = vaSnap.docs.first.data()['tenantId'] as String?;
        if (uid != null) {
          final uDoc = await fs.collection('users').doc(uid).get();
          if (uDoc.exists) {
            setState(() {
              _currentUserId = uDoc.id;
              _userData = uDoc.data();
              _searching = false;
            });
            return;
          }
        }
      }

      setState(() {
        _searching = false;
        _errorMessage = 'No customer found matching "$query".';
      });
    } catch (e) {
      setState(() {
        _searching = false;
        _errorMessage = 'Search error: $e';
      });
    }
  }

  Future<void> _loadCustomerById(String uid) async {
    setState(() => _searching = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snap.exists) {
        setState(() {
          _currentUserId = snap.id;
          _userData = snap.data();
          _searchController.text = _userData?['email'] ?? uid;
          _searching = false;
        });
      } else {
        setState(() {
          _searching = false;
          _errorMessage = 'User record not found.';
        });
      }
    } catch (e) {
      setState(() {
        _searching = false;
        _errorMessage = 'Error loading user: $e';
      });
    }
  }

  Future<void> _toggleFreezeAccount() async {
    if (_currentUserId == null || _userData == null) return;
    final isCurrentlySuspended = _userData?['isSuspended'] == true;
    final newStatus = !isCurrentlySuspended;

    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
        'isSuspended': newStatus,
        'status': newStatus ? 'suspended' : 'active',
      });

      // Record audit log
      final agent = FirebaseAuth.instance.currentUser?.email ?? 'support_agent';
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': newStatus ? 'SUSPEND_USER' : 'UNSUSPEND_USER',
        'details': 'Account status changed to ${newStatus ? 'SUSPENDED' : 'ACTIVE'} for $_currentUserId',
        'actorEmail': agent,
        'targetId': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _userData?['isSuspended'] = newStatus;
        _userData?['status'] = newStatus ? 'suspended' : 'active';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'Account FROZEN / SUSPENDED' : 'Account REACTIVATED'),
          backgroundColor: newStatus ? Colors.red.shade800 : Colors.green.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleKycVerification() async {
    if (_currentUserId == null || _userData == null) return;
    final isVerified = _userData?['isVerified'] == true;
    final newVerified = !isVerified;

    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
        'isVerified': newVerified,
        'verificationStatus': newVerified ? 'verified' : 'unverified',
      });

      setState(() {
        _userData?['isVerified'] = newVerified;
        _userData?['verificationStatus'] = newVerified ? 'verified' : 'unverified';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newVerified ? 'Customer KYC MANUALLY VERIFIED' : 'KYC Verification Removed'),
          backgroundColor: const Color(0xFF0F172A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSendDirectAlertModal() {
    if (_currentUserId == null) return;
    final titleController = TextEditingController(text: 'Important Update from AGENT Support');
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notification_important_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 10),
            Text('Send Priority In-App Alert', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Alert Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message Content',
                hintText: 'e.g. Your virtual account transfer has been credited successfully.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final msg = messageController.text.trim();
              if (msg.isEmpty) return;

              Navigator.pop(dialogCtx);
              try {
                await FirebaseFirestore.instance.collection('notifications').add({
                  'userId': _currentUserId,
                  'title': titleController.text.trim(),
                  'message': msg,
                  'type': 'support_alert',
                  'isRead': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Priority alert sent to user device!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to send notification: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Send Alert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddStaffNoteModal() {
    if (_currentUserId == null) return;
    final noteController = TextEditingController();
    String noteCategory = 'ESCROW_ISSUE';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF0F172A)),
              SizedBox(width: 10),
              Text('Add Internal Staff Note', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: noteCategory,
                decoration: InputDecoration(
                  labelText: 'Case Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'ESCROW_ISSUE', child: Text('Escrow & Handshake PIN')),
                  DropdownMenuItem(value: 'TRANSFER_DELAY', child: Text('Bank Transfer Delay')),
                  DropdownMenuItem(value: 'KYC_VERIFICATION', child: Text('KYC / NIN Verification')),
                  DropdownMenuItem(value: 'PROPERTY_DISPUTE', child: Text('Property / Landlord Dispute')),
                  DropdownMenuItem(value: 'GENERAL_SUPPORT', child: Text('General Account Inquiry')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => noteCategory = val);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Staff Case Note',
                  hintText: 'e.g. Customer called about NUBAN delay. Resolved with manual re-query.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final note = noteController.text.trim();
                if (note.isEmpty) return;

                Navigator.pop(dialogCtx);
                final agent = FirebaseAuth.instance.currentUser?.email ?? 'support_staff';
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUserId)
                      .collection('staff_notes')
                      .add({
                    'category': noteCategory,
                    'note': note,
                    'agentEmail': agent,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Staff note recorded in customer file!')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save Note', style: TextStyle(color: Colors.white)),
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
        title: const Text('Customer 360° Diagnosis Console'),
        centerTitle: false,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Universal Search Bar
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      hintText: 'Search by User ID, Email, Phone, or NUBAN...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _searchCustomer(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: _searching ? null : _searchCustomer,
                  child: _searching
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Inspect', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),

          if (_userData == null && !_searching)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search_rounded, size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'Customer Diagnosis Console',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter customer ID, email, phone number, or virtual account number above to inspect full customer profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else if (_userData != null) ...[
            // Customer Header Card
            _buildCustomerHeaderCard(),

            // Diagnosis Tabs
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF0F172A),
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.handshake_rounded, size: 20), text: 'Escrows'),
                  Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 20), text: 'Wallet & NUBAN'),
                  Tab(icon: Icon(Icons.warning_amber_rounded, size: 20), text: 'Errors & Logs'),
                  Tab(icon: Icon(Icons.note_alt_rounded, size: 20), text: 'Staff Notes'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEscrowsTab(),
                  _buildWalletTab(),
                  _buildErrorLogsTab(),
                  _buildStaffNotesTab(),
                ],
              ),
            ),

            // Support Quick Action Strip
            _buildQuickActionStrip(),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerHeaderCard() {
    final name = _userData?['fullName'] ?? 'Unnamed User';
    final email = _userData?['email'] ?? 'No email';
    final phone = _userData?['phone'] ?? _userData?['phoneNumber'] ?? 'No phone';
    final role = (_userData?['role'] ?? 'tenant').toString().toUpperCase();
    final isVerified = _userData?['isVerified'] == true;
    final isSuspended = _userData?['isSuspended'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF0F172A),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: role == 'LANDLORD' ? Colors.blue.shade50 : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: role == 'LANDLORD' ? Colors.blue.shade800 : Colors.purple.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isSuspended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'FROZEN',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(width: 12),
                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('UID: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    Text(
                      _currentUserId ?? '',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _currentUserId ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UID copied to clipboard!')),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF0284C7)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isVerified ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isVerified ? Icons.verified_rounded : Icons.pending_rounded,
                            size: 13,
                            color: isVerified ? Colors.green.shade700 : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? 'KYC Verified' : 'KYC Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isVerified ? Colors.green.shade700 : Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppLoader(size: 28));
        }

        final docs = snapshot.data?.docs.where((doc) {
          final data = doc.data();
          return data['tenantId'] == _currentUserId || data['landlordId'] == _currentUserId;
        }).toList() ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handshake_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text('No escrow transactions found for this customer.'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final tx = docs[index].data();
            final txId = docs[index].id;
            final amount = tx['amount'] ?? 0;
            final status = (tx['status'] ?? 'pending').toString().toUpperCase();
            final propertyTitle = tx['propertyTitle'] ?? tx['propertyAddress'] ?? 'Property Rental';
            final pin = tx['handshakePin'] ?? tx['deliveryPin'] ?? '------';
            final isTenant = tx['tenantId'] == _currentUserId;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              propertyTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'TX ID: $txId',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rent Amount: ₦${NumberFormat('#,###').format(amount)} (${isTenant ? "As Tenant" : "As Landlord"})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // PIN Diagnostic Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0F172A).withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Handshake Settlement Key PIN:',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pin.toString(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: 'Copy PIN',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: pin.toString()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('PIN copied to clipboard')),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.send_to_mobile_rounded, color: Color(0xFF6366F1), size: 20),
                              tooltip: 'Resend PIN Notification to Customer',
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('notifications').add({
                                  'userId': _currentUserId,
                                  'title': 'Your Settlement PIN Reminder',
                                  'message': 'Your Handshake Settlement PIN for $propertyTitle is: $pin',
                                  'type': 'escrow_pin',
                                  'isRead': false,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('PIN sent directly to customer device!')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _statusColor(String status) {
    if (status.contains('SETTLED') || status.contains('RELEASED') || status.contains('SUCCESS')) {
      return const Color(0xFF10B981);
    }
    if (status.contains('PENDING') || status.contains('AWAITING')) {
      return const Color(0xFFF59E0B);
    }
    if (status.contains('DISPUTE')) {
      return Colors.red;
    }
    return const Color(0xFF6366F1);
  }

  Widget _buildWalletTab() {
    final balance = _userData?['walletBalance'] ?? _userData?['balance'] ?? 0;
    final virtualAcc = _userData?['virtualAccountNumber'] ?? 'Not Generated Yet';
    final virtualBank = _userData?['virtualBankName'] ?? 'Wema Bank (Flutterwave)';
    final virtualName = _userData?['virtualAccountName'] ?? _userData?['fullName'] ?? 'AGENT ESCROW';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Customer Available Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                '₦${NumberFormat('#,###.00').format(balance)}',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Divider(color: Colors.white24, height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assigned Virtual NUBAN Account:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        virtualAcc.toString(),
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      Text(
                        '$virtualBank • $virtualName',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: virtualAcc.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Virtual account copied!')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('Recent Ledger Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('transactions')
              .where('tenantId', isEqualTo: _currentUserId)
              .limit(10)
              .snapshots(),
          builder: (context, snap) {
            final txs = snap.data?.docs ?? [];
            if (txs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('No ledger transactions on record.')),
              );
            }

            return Column(
              children: txs.map((t) {
                final d = t.data();
                final amt = d['amount'] ?? 0;
                final type = d['type'] ?? 'PAYMENT';
                final status = d['status'] ?? 'COMPLETED';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type.toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Status: $status', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        ],
                      ),
                      Text(
                        '₦${NumberFormat('#,###').format(amt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildErrorLogsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('user_behavior_logs')
          .where('userEmail', isEqualTo: _userData?['email'])
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final logs = snapshot.data?.docs ?? [];

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 54, color: Colors.green.shade400),
                const SizedBox(height: 12),
                const Text('No recent failure or security alerts on this user account.'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final data = logs[index].data();
            final event = data['eventType'] ?? data['action'] ?? 'EVENT';
            final desc = data['details'] ?? data['description'] ?? '';
            final isFail = event.toString().toLowerCase().contains('fail') ||
                event.toString().toLowerCase().contains('error');

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isFail ? Colors.red.shade200 : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    isFail ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                    color: isFail ? Colors.red : Colors.blueGrey,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: isFail ? Colors.red : Colors.black87)),
                        const SizedBox(height: 2),
                        Text(desc.toString(), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStaffNotesTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('staff_notes')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final notes = snapshot.data?.docs ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Internal Support Case History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton.icon(
                    onPressed: _showAddStaffNoteModal,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Case Note'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notes.isEmpty
                  ? Center(
                      child: Text('No previous staff notes recorded for this customer.', style: TextStyle(color: Colors.grey.shade500)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final n = notes[index].data();
                        final cat = n['category'] ?? 'NOTE';
                        final noteText = n['note'] ?? '';
                        final agent = n['agentEmail'] ?? 'staff';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      cat.toString(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    'Agent: $agent',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(noteText.toString(), style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionStrip() {
    final isSuspended = _userData?['isSuspended'] == true;
    final isVerified = _userData?['isVerified'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isSuspended ? Colors.green : Colors.red,
                side: BorderSide(color: isSuspended ? Colors.green : Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(isSuspended ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 18),
              label: Text(isSuspended ? 'Unfreeze' : 'Freeze User'),
              onPressed: _toggleFreezeAccount,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(isVerified ? Icons.remove_moderator_rounded : Icons.verified_user_rounded, size: 18),
              label: Text(isVerified ? 'Revoke KYC' : 'Verify KYC'),
              onPressed: _toggleKycVerification,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.notification_important_rounded, size: 18),
            label: const Text('Send Alert'),
            onPressed: _showSendDirectAlertModal,
          ),
        ],
      ),
    );
  }
}
