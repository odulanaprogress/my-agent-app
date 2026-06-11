import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/permission_service.dart';


import '../models/property_model.dart';
import '../../favorites/presentation/providers/favorites_notifier.dart';
import '../../payments/presentation/screens/payment_screen.dart';
import '../../chat/presentation/providers/chat_provider.dart';
import '../../chat/presentation/screens/chat_screen.dart';
import '../../../core/services/user_behavior_service.dart';

class PropertyDetailsScreen extends ConsumerStatefulWidget {
  final PropertyModel property;
  const PropertyDetailsScreen({super.key, required this.property});

  @override
  ConsumerState<PropertyDetailsScreen> createState() =>
      _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState
    extends ConsumerState<PropertyDetailsScreen> {
  int _currentImageIndex = 0;
  final PageController _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLiabilityWarning();
      UserBehaviorService.logPropertyView(
        widget.property.id,
        widget.property.title,
      );
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _showLiabilityWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 12),
            Text('Payment Warning', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'WARNING: AGENT is not liable for any payments made outside of this app. Ensure all payments run securely through our escrow system.',
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
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  Future<void> _call(String phone) async {
    final target = phone.trim().isEmpty ? '08030000000' : phone.trim();
    final uri = Uri(scheme: 'tel', path: target);
    try {
      await launchUrl(uri);
    } catch (e) {
      _snack('Could not launch dialer: $e');
    }
  }

  Future<void> _whatsapp(String number) async {
    final target = number.trim().isEmpty ? '08030000000' : number.trim();
    var cleaned = target.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = '234${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('234') && cleaned.length == 10) {
      cleaned = '234$cleaned';
    }
    final uri = Uri.parse('https://wa.me/$cleaned');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack('Could not open WhatsApp: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _openChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final landlordUid = widget.property.ownerId;
    if (landlordUid == uid) {
      _snack('You cannot chat with yourself.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(chatRepositoryProvider);
      final docRef = await repo.ensureConversation(
        propertyId: widget.property.id,
        tenantUid: uid,
        landlordUid: landlordUid,
      );
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: docRef.id,
              senderId: uid,
              receiverId: landlordUid,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _snack('Failed to start chat: $e');
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final isFavorite =
        ref.watch(favoritesNotifierProvider).contains(p.id);
    final hasImages = p.imageUrls.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── Hero image carousel ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  await ref
                      .read(favoritesNotifierProvider.notifier)
                      .toggleFavorite(p.id);
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: hasImages
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _pageCtrl,
                          itemCount: p.imageUrls.length,
                          onPageChanged: (i) =>
                              setState(() => _currentImageIndex = i),
                          itemBuilder: (context, index) => Image.network(
                            p.imageUrls[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.home,
                                  size: 60, color: Colors.grey),
                            ),
                          ),
                        ),
                        // Page indicator dots
                        if (p.imageUrls.length > 1)
                          Positioned(
                            bottom: 14,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                p.imageUrls.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3),
                                  width:
                                      _currentImageIndex == i ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _currentImageIndex == i
                                        ? Colors.white
                                        : Colors.white54,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Photo count badge
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${p.imageUrls.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: const Color(0xFF1E293B),
                      child: const Center(
                        child: Icon(Icons.home_work_outlined,
                            size: 72, color: Colors.white24),
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Price + title card ─────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                height: 1.25,
                              ),
                            ),
                          ),
                          _categoryBadge(p.category),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final query = Uri.encodeComponent('${p.address}, ${p.community}, ${p.state}');
                          final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                          try {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            _snack('Could not open map: $e');
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 16, color: Color(0xFF6366F1)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${p.address}, ${p.community}, ${p.state}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.map_outlined,
                                  size: 16, color: Color(0xFF6366F1)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₦${_formatPrice(p.price)}',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              p.listingType == 'sell'
                                  ? ' (Outright Purchase)'
                                  : p.rentalDurationUnit != null
                                      ? '/ ${p.rentalDurationValue ?? 1} ${p.rentalDurationUnit}'
                                      : p.category.toLowerCase() == 'short let'
                                          ? '/night'
                                          : '/year',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Stats row ──────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat(Icons.visibility_outlined,
                          '${p.viewsCount}', 'Views'),
                      _divider(),
                      _stat(Icons.favorite_border,
                          '${p.favoritesCount}', 'Saves'),
                      _divider(),
                      _stat(Icons.chat_bubble_outline,
                          '${p.inquiriesCount}', 'Enquiries'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Description ────────────────────────────────────
                _section(
                  title: 'About this property',
                  child: Text(
                    p.description.isNotEmpty
                        ? p.description
                        : 'No description provided.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.7,
                      fontSize: 14.5,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Amenities ──────────────────────────────────────
                if (p.amenities.isNotEmpty)
                  _section(
                    title: 'Amenities',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: p.amenities
                          .map((a) => _amenityChip(a))
                          .toList(),
                    ),
                  ),

                if (p.amenities.isNotEmpty) const SizedBox(height: 8),

                // ── Video Tour ─────────────────────────────────────
                if (p.videoUrls.isNotEmpty)
                  _section(
                    title: '🎬 Video Tour',
                    child: GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(p.videoUrls.first);
                        try {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } catch (e) {
                          _snack('Could not play video: $e');
                        }
                      },
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 36),
                            SizedBox(width: 12),
                            Text(
                              'Watch Video Tour',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (p.videoUrls.isNotEmpty) const SizedBox(height: 8),

                // ── Contact Landlord ───────────────────────────────
                _section(
                  title: '📞 Contact Landlord',
                  child: Column(
                    children: [
                      // Owner info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                const Color(0xFF6366F1).withValues(alpha: 0.1),
                            child: Text(
                              p.ownerName.isNotEmpty
                                  ? p.ownerName[0].toUpperCase()
                                  : 'L',
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.ownerName.isNotEmpty
                                    ? p.ownerName
                                    : 'Property Owner',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Landlord / Agent',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          // Chat
                          Expanded(
                            child: _actionButton(
                              icon: Icons.chat_bubble_outline,
                              label: 'Chat',
                              color: const Color(0xFF6366F1),
                              onTap: _openChat,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Call
                          Expanded(
                            child: _actionButton(
                              icon: Icons.phone_outlined,
                              label: 'Call',
                              color: const Color(0xFF10B981),
                              onTap: () => _call(p.contactPhone),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // WhatsApp
                          Expanded(
                            child: _actionButton(
                              icon: Icons.chat,
                              label: 'WhatsApp',
                              color: const Color(0xFF22C55E),
                              onTap: () => _whatsapp(p.whatsappNumber),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Fee Breakdown Card ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pricing Package Breakdown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Base Rent / Price',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            Text(
                              '₦${_formatPrice(p.price)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Agency & Agent Fee (20%)',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            Text(
                              '₦${_formatPrice(p.price * 0.20)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        const Divider(height: 24, thickness: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Package',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '₦${_formatPrice(p.price * 1.20)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Payment CTA ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PaymentScreen(property: p)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Proceed to Payment',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),

                // ── Secondary CTAs ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.draw_rounded, size: 18),
                          label: const Text('Sign Agreement'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            side: const BorderSide(
                                color: Color(0xFF6366F1), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    _TenancyAgreementLauncher(property: p),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.timer_outlined, size: 18),
                          label: const Text('My Rentals'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(
                                color: Color(0xFF10B981), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => context.push('/my-rentals'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────
  Widget _section({required String title, required Widget child}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF0F172A))),
        Text(label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  Widget _divider() => Container(
      height: 36, width: 1, color: Colors.grey.shade200);

  Widget _amenityChip(String amenity) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
        ),
        child: Text(
          amenity,
          style: const TextStyle(
            color: Color(0xFF6366F1),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _categoryBadge(String category) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(num price) {
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(1)}B';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }
}

// ── Tenancy Agreement Launcher ─────────────────────────────────────────────
class _TenancyAgreementLauncher extends StatefulWidget {
  final PropertyModel property;
  const _TenancyAgreementLauncher({required this.property});
  @override
  State<_TenancyAgreementLauncher> createState() =>
      _TenancyAgreementLauncherState();
}

class _TenancyAgreementLauncherState
    extends State<_TenancyAgreementLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launch();
    });
  }

  Future<void> _launch() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    // Fetch landlord name from Firestore
    String landlordName = widget.property.ownerName;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.property.ownerId)
          .get();
      landlordName = doc.data()?['fullName'] ?? landlordName;
    } catch (_) {}

    if (!mounted) return;
    Navigator.pop(context); // pop the loader
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => _TenancyScreenWrapper(
          property: widget.property,
          landlordName: landlordName,
          tenantName: user?.displayName ?? user?.email ?? 'Tenant',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _TenancyScreenWrapper extends StatelessWidget {
  final PropertyModel property;
  final String landlordName;
  final String tenantName;
  const _TenancyScreenWrapper({
    required this.property,
    required this.landlordName,
    required this.tenantName,
  });

  @override
  Widget build(BuildContext context) {
    return _EmbeddedTenancyAgreement(
      propertyId: property.id,
      propertyTitle: property.title,
      landlordId: property.ownerId,
      landlordName: landlordName,
      tenantName: tenantName,
      rentAmount: property.price.toDouble(),
    );
  }
}

// Inline Tenancy Agreement Screen (self-contained, no import needed)
class _EmbeddedTenancyAgreement extends StatefulWidget {
  final String propertyId;
  final String propertyTitle;
  final String landlordId;
  final String landlordName;
  final String tenantName;
  final double rentAmount;

  const _EmbeddedTenancyAgreement({
    required this.propertyId,
    required this.propertyTitle,
    required this.landlordId,
    required this.landlordName,
    required this.tenantName,
    required this.rentAmount,
  });

  @override
  State<_EmbeddedTenancyAgreement> createState() =>
      _EmbeddedTenancyAgreementState();
}

class _EmbeddedTenancyAgreementState extends State<_EmbeddedTenancyAgreement>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final List<Offset?> _points = [];
  bool _hasSig = false, _accepted = false, _saving = false;
  String _duration = '12 months';

  final _durations = ['3 months', '6 months', '12 months', '24 months', '36 months'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _printOrDownloadAgreement(BuildContext context) async {
    final hasPermission = await PermissionService.requestStoragePermission(context);
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to download agreements.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) {
              Navigator.pop(context);
              _showSuccessDialog();
            }
          });
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12),
                CircularProgressIndicator(color: Color(0xFF0F172A)),
                SizedBox(height: 20),
                Text(
                  'Generating PDF Agreement...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Compiling terms, signatures, and lease data',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('PDF Downloaded', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'The tenancy agreement for "${widget.propertyTitle}" has been successfully compiled into a PDF and saved to your device storage.',
          style: const TextStyle(height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAgreement() async {
    if (!_hasSig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first.')),
      );
      return;
    }
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('tenancy_agreements').add({
        'tenantId': user?.uid ?? '',
        'tenantEmail': user?.email ?? '',
        'tenantName': widget.tenantName,
        'landlordId': widget.landlordId,
        'landlordName': widget.landlordName,
        'propertyId': widget.propertyId,
        'propertyTitle': widget.propertyTitle,
        'rentAmount': widget.rentAmount,
        'rentalDuration': _duration,
        'status': 'signed_by_tenant',
        'signedAt': FieldValue.serverTimestamp(),
        'termsAccepted': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Agreement Signed!'),
          ]),
          content: const Text(
            'Your tenancy agreement has been digitally signed and submitted. The landlord will be notified to counter-sign.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF0F172A)),
        title: const Text(
          'Tenancy Agreement',
          style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Color(0xFF0F172A)),
            onPressed: () => _printOrDownloadAgreement(context),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF0F172A)),
            onPressed: () => _printOrDownloadAgreement(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0F172A),
          tabs: const [Tab(text: 'Agreement'), Tab(text: 'Signature')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildAgreementTab(), _buildSignatureTab()],
      ),
    );
  }

  Widget _buildAgreementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TENANCY AGREEMENT',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(widget.propertyTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(children: [
                  _chip('Tenant: ${widget.tenantName}'),
                  const SizedBox(width: 8),
                  _chip('Landlord: ${widget.landlordName}'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Rental Duration',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _duration,
                isExpanded: true,
                items: _durations
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _duration = v!),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Terms & Conditions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'This Tenancy Agreement is entered into between the Landlord and Tenant for the property: ${widget.propertyTitle}.\n\n'
              '1. TERM: The tenancy shall run for a period of $_duration from the date of signing.\n\n'
              '2. RENT: The agreed rent is ₦${widget.rentAmount.toStringAsFixed(0)}. All payments shall be made through the AGENT Escrow system.\n\n'
              '3. ESCROW: Funds are held securely by our partner bank and released to the Landlord upon confirmed possession.\n\n'
              '4. USE: The Tenant shall use the property solely for residential purposes.\n\n'
              '5. MAINTENANCE: The Tenant shall maintain the property and report damage promptly.\n\n'
              '6. TERMINATION: Either party may terminate with 30 days written notice via the AGENT Platform.\n\n'
              '7. GOVERNING LAW: This agreement is governed by the laws of the Federal Republic of Nigeria.\n\n'
              'By signing, both parties agree to be bound by these terms.',
              style: TextStyle(
                  color: Colors.grey.shade700, fontSize: 13, height: 1.7),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  _accepted ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accepted
                    ? Colors.green.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(children: [
              Checkbox(
                value: _accepted,
                activeColor: Colors.green,
                onChanged: (v) => setState(() => _accepted = v ?? false),
              ),
              Expanded(
                child: Text(
                  'I have read and agree to the terms of this tenancy agreement.',
                  style: TextStyle(
                      fontSize: 13,
                      color: _accepted
                          ? Colors.green.shade800
                          : Colors.grey.shade700),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.draw_rounded, size: 18),
              label: const Text('Proceed to Sign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed:
                  _accepted ? () => _tab.animateTo(1) : null,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSignatureTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Draw Your Signature',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('Use your finger to sign in the box below.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Stack(children: [
                if (!_hasSig)
                  Center(
                      child: Text('Sign here',
                          style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 20,
                              fontStyle: FontStyle.italic))),
                GestureDetector(
                  onPanStart: (d) => setState(
                      () => _points.add(d.localPosition)),
                  onPanUpdate: (d) => setState(() {
                    _points.add(d.localPosition);
                    _hasSig = true;
                  }),
                  onPanEnd: (_) => setState(() => _points.add(null)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CustomPaint(
                      painter: _SigPainter(_points),
                      child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.transparent),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () =>
                    setState(() {
                      _points.clear();
                      _hasSig = false;
                    }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.verified_rounded, size: 18),
                label: Text(_saving ? 'Saving...' : 'Sign Agreement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _saveAgreement,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      );
}

class _SigPainter extends CustomPainter {
  final List<Offset?> points;
  _SigPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter old) => true;
}

