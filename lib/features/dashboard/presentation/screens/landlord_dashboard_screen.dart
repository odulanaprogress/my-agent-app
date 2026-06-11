import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../../core/services/property_service.dart';
import '../../../../core/widgets/property_card.dart';
import '../../../../features/properties/models/property_model.dart';
import '../../../../features/properties/screens/edit_property_screen.dart';
import '../../../../features/landlord/screens/landlord_profile_screen.dart';
import '../../../../features/chat/presentation/screens/chat_screen.dart';
import '../../../dashboard/presentation/screens/tenant_dashboard_screen.dart';

class LandlordDashboardScreen extends ConsumerStatefulWidget {
  const LandlordDashboardScreen({super.key});

  @override
  ConsumerState<LandlordDashboardScreen> createState() =>
      _LandlordDashboardScreenState();
}

class _LandlordDashboardScreenState
    extends ConsumerState<LandlordDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  /// When true, show tenant's view of properties (read-only browse)
  bool _tenantViewMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showEscrowWarning();
    });
  }

  void _showEscrowWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF1E3A8A), size: 28),
            SizedBox(width: 12),
            Text('Escrow Notice', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Notice: All payments run through escrow. Funds are securely held by our partner bank and will drop to your wallet only once the tenant receives possession of the property.',
          style: TextStyle(height: 1.5, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _getBedroomsCount(PropertyModel p) {
    final match = p.amenities.firstWhere(
      (a) => a.toLowerCase().contains('bed') || a.toLowerCase().contains('br'),
      orElse: () => '',
    );
    if (match.isNotEmpty) {
      final number = RegExp(r'\d+').firstMatch(match)?.group(0);
      if (number != null) return number;
    }
    return '2';
  }

  String _getBathroomsCount(PropertyModel p) {
    final match = p.amenities.firstWhere(
      (a) => a.toLowerCase().contains('bath') || a.toLowerCase().contains('ba'),
      orElse: () => '',
    );
    if (match.isNotEmpty) {
      final number = RegExp(r'\d+').firstMatch(match)?.group(0);
      if (number != null) return number;
    }
    return '2';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await ref.read(authNotifierProvider.notifier).logout();
      if (!context.mounted) return;
      context.go('/login');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    // If tenant-view mode, show the tenant dashboard
    if (_tenantViewMode) {
      return _TenantViewWrapper(
        onExit: () => setState(() => _tenantViewMode = false),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // Tenant View toggle
          Tooltip(
            message: 'Preview as Tenant',
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton(
                iconSize: 22,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _tenantViewMode = true),
                icon: const Icon(Icons.visibility_outlined,
                    color: Color(0xFF6366F1), size: 22),
              ),
            ),
          ),
          // Profile
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton(
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LandlordProfileScreen()),
              ),
              icon: const Icon(Icons.account_circle_outlined,
                  color: Color(0xFF0F172A), size: 22),
              tooltip: 'My Profile',
            ),
          ),
          // Logout
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_outlined,
                  color: Colors.redAccent, size: 20),
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 300));
              setState(() {});
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 6),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OWNER CONSOLE',
                          style: TextStyle(
                            color: Color(0xFF1565C0),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'My Properties',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (user != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Welcome back, ${user.fullName}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Financial metrics
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ESTIMATED MONTHLY EARNINGS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const Icon(Icons.trending_up_rounded,
                              color: Colors.green, size: 20),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '₦0.00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFinancialDetail(
                              label: 'On-Time Payments',
                              value: '0',
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          Expanded(
                            child: _buildFinancialDetail(
                              label: 'Late Payments',
                              value: '0',
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Add Property',
                        onTap: () => context.push('/properties/upload'),
                        color: const Color(0xFF0F172A),
                        isFilled: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.visibility_outlined,
                        label: 'Tenant View',
                        onTap: () => setState(() => _tenantViewMode = true),
                        color: const Color(0xFF6366F1),
                        isFilled: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Search
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by title, location, or amenities...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search_outlined,
                          color: Color(0xFF0F172A), size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF0F172A)),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 24),

                // Tabs: My Listings | Tenant Messages
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    onTap: (_) => setState(() {}),
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF0F172A),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tabs: const [
                      Tab(text: 'My Listings'),
                      Tab(text: 'Tenant Chats'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tab body
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _tabController.index == 0
                      ? _buildMyListings()
                      : _buildTenantCommunications(),
                ),

                const SizedBox(height: 24),

                // Operations section
                const Text(
                  'Operations & Support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),

                _buildNavigationActionRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'Payment History',
                  subtitle: 'Track rent statements & invoices',
                  onTap: () => context.push('/wallet'),
                ),
                const SizedBox(height: 12),

                _buildNavigationActionRow(
                  icon: Icons.draw_rounded,
                  title: 'Tenancy Agreements',
                  subtitle: 'View & manage signed agreements',
                  onTap: () => context.push('/my-rentals'),
                ),
                const SizedBox(height: 12),

                _buildNavigationActionRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'My Wallet & Escrow',
                  subtitle: 'View available balance & escrow funds',
                  onTap: () => context.push('/wallet'),
                ),
                const SizedBox(height: 12),

                _buildNavigationActionRow(
                  icon: Icons.forum_outlined,
                  title: 'Tenant Communications',
                  subtitle: 'Direct notifications & instant chat messaging',
                  onTap: () {
                    _tabController.animateTo(1);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 30),

              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // My Listings Tab
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMyListings() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<List<PropertyModel>>(
      stream: PropertyService().getLandlordProperties(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Failed to load properties: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }

        var properties = snapshot.data ?? const [];

        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          properties = properties
              .where(
                (p) =>
                    p.title.toLowerCase().contains(query) ||
                    p.location.toLowerCase().contains(query) ||
                    p.amenities.any((a) => a.toLowerCase().contains(query)),
              )
              .toList();
        }

        if (properties.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work_outlined,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 14),
                Text(
                  'No properties uploaded yet.',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: properties.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final p = properties[index];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.show_chart_rounded,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${p.viewsCount} views',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildStatusBadge(p),
                        const SizedBox(width: 8),
                        // Edit Property button
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditPropertyScreen(property: p),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 12, color: Color(0xFF6366F1)),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                PropertyCard(
                  image: p.imageUrl,
                  title: p.title,
                  location: p.location,
                  price: '₦${p.price.toStringAsFixed(0)}',
                  bedrooms: _getBedroomsCount(p),
                  bathrooms: _getBathroomsCount(p),
                  onTap: () {
                    context.push('/properties/details', extra: p);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tenant Communications Tab
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTenantCommunications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Not logged in.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final rawDocs = snap.data?.docs ?? [];
        final docs = rawDocs.toList()
          ..sort((a, b) {
            final aTime = a.data()['lastMessageTime'] as Timestamp?;
            final bTime = b.data()['lastMessageTime'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                Text(
                  'No tenant messages yet.',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Messages from tenants will appear here.',
                  style:
                      TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final conversationId = docs[index].id;
            final participants =
                (data['participants'] as List?)?.cast<String>() ?? [];
            final tenantUid =
                participants.firstWhere((p) => p != uid, orElse: () => '');
            final lastMessage = (data['lastMessage'] ?? '').toString();
            final propertyId = (data['propertyId'] ?? '').toString();
            final ts = data['updatedAt'] as Timestamp?;
            final timeStr = ts != null ? _fmtTime(ts.toDate()) : '';

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(tenantUid)
                  .get(),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data();
                final tenantName =
                    userData?['fullName'] ?? userData?['name'] ?? 'Tenant';

                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('properties')
                      .doc(propertyId)
                      .get(),
                  builder: (context, propSnap) {
                    final propData = propSnap.data?.data();
                    final propertyTitle =
                        propData?['title'] ?? 'Property Chat';
                    final imgs =
                        (propData?['imageUrls'] as List?)?.cast<String>() ??
                            [];
                    final propertyImage =
                        imgs.isNotEmpty ? imgs.first : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  conversationId: conversationId,
                                  senderId: uid,
                                  receiverId: tenantUid,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Property thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: propertyImage.isNotEmpty
                                        ? Image.network(
                                            propertyImage,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (ctx, err, st) => Container(
                                              width: 52,
                                              height: 52,
                                              color: Colors.grey.shade100,
                                              child: const Icon(
                                                  Icons.home_work),
                                            ),
                                          )
                                        : Container(
                                            width: 52,
                                            height: 52,
                                            color: Colors.grey.shade100,
                                            child: const Icon(Icons.home_work),
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          propertyTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'From: $tenantName',
                                          style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          lastMessage.isEmpty
                                              ? 'No messages'
                                              : lastMessage,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade400),
                                      ),
                                      const SizedBox(height: 4),
                                      const Icon(Icons.chevron_right_rounded,
                                          color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper widgets
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFinancialDetail({
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required bool isFilled,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isFilled ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isFilled ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isFilled ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PropertyModel p) {
    Color bg;
    Color fg;
    String text;

    if (p.isApproved) {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
      text = 'ACTIVE';
    } else if (p.approvalStatus == 'rejected') {
      bg = Colors.red.shade50;
      fg = Colors.red;
      text = 'REJECTED';
    } else {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade800;
      text = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(30)),
      child: Text(
        text,
        style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildNavigationActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon,
                        color: const Color(0xFF0F172A), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(icon, color: Colors.grey.shade300, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tenant View Wrapper — shows tenant dashboard with an exit banner
// ─────────────────────────────────────────────────────────────────────────────
class _TenantViewWrapper extends StatelessWidget {
  final VoidCallback onExit;
  const _TenantViewWrapper({required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Show the real tenant dashboard so landlords see what tenants see
        const TenantDashboardScreen(),

        // Top banner indicating landlord is in preview mode
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              color: const Color(0xFF6366F1),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 6,
                bottom: 10,
                left: 16,
                right: 16,
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tenant Preview Mode',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: onExit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Exit Preview',
                        style: TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
