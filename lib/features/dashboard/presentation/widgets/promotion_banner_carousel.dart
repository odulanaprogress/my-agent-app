import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PromotionBannerCarousel extends StatefulWidget {
  const PromotionBannerCarousel({super.key});

  @override
  State<PromotionBannerCarousel> createState() => _PromotionBannerCarouselState();
}

class _PromotionBannerCarouselState extends State<PromotionBannerCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  static const int _kLoopFactor = 1000;

  static const List<_BannerSlideData> _slides = [
    _BannerSlideData(
      tag: 'EXCLUSIVE OFFERS',
      tagColor: Colors.amber,
      badge: 'Verified Only',
      title: 'Find Your Dream Sanctuary',
      subtitle: 'Explore premium verified properties with smart features.',
      gradient: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
      icon: Icons.home_work_outlined,
      route: '/search',
    ),
    _BannerSlideData(
      tag: 'SAFETY UPDATE',
      tagColor: Color(0xFF10B981),
      badge: 'Escrow Protected',
      title: 'Protected Rent Payments',
      subtitle: 'Your funds are safely held until you inspect and accept the keys.',
      gradient: [Color(0xFF0F172A), Color(0xFF065F46)],
      icon: Icons.verified_user_outlined,
      route: '/escrow',
    ),
    _BannerSlideData(
      tag: 'LATEST FEATURE',
      tagColor: Color(0xFFA78BFA),
      badge: 'AI Powered',
      title: 'Instant 24/7 AI Realtor',
      subtitle: 'Chat anytime to compare rents, neighborhoods, and schedule viewings.',
      gradient: [Color(0xFF0F172A), Color(0xFF4338CA)],
      icon: Icons.smart_toy_outlined,
      route: '/ai-chat',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final initialPage = _slides.length * (_kLoopFactor ~/ 2);
    _pageController = PageController(initialPage: initialPage);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length * _kLoopFactor,
            onPageChanged: (index) {
              setState(() => _currentPage = index % _slides.length);
            },
            itemBuilder: (context, index) {
              final slide = _slides[index % _slides.length];
              return GestureDetector(
                onTap: () {
                  if (slide.route.isNotEmpty) {
                    try {
                      context.push(slide.route);
                    } catch (_) {}
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: slide.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: slide.gradient.last.withValues(alpha: 0.18),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Decorative background watermark icon
                      Positioned(
                        right: -10,
                        bottom: -15,
                        child: Icon(
                          slide.icon,
                          size: 90,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                slide.tag,
                                style: TextStyle(
                                  color: slide.tagColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  slide.badge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            slide.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            slide.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Animated Dot Indicator
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final isActive = _currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  height: 3.5,
                  width: isActive ? 16 : 4,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerSlideData {
  final String tag;
  final Color tagColor;
  final String badge;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final String route;

  const _BannerSlideData({
    required this.tag,
    required this.tagColor,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.route,
  });
}
