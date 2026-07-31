import 'package:flutter/material.dart';

/// A branded loading indicator that animates the app logo with a heartbeat
/// pulse effect — replacing the generic CircularProgressIndicator across
/// the entire app.
///
/// Usage:
///   • Large (full-page): AppLoader()  or  AppLoader(size: 56)
///   • Small (in buttons): AppLoader(size: 22)  — renders a compact pulsing logo
class AppLoader extends StatefulWidget {
  final double size;
  const AppLoader({super.key, this.size = 56.0});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _ring1Anim;
  late final Animation<double> _ring2Anim;
  late final Animation<double> _ringOpacity1;
  late final Animation<double> _ringOpacity2;

  @override
  void initState() {
    super.initState();

    // Heartbeat controller — two quick beats then a pause
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Ripple ring controller
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Scale: 1.0 → 1.18 → 1.0 → 1.12 → 1.0  (double-beat heartbeat)
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 46), // rest
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 46),
    ]).animate(_pulseController);

    // Ripple rings expand outward and fade
    _ring1Anim = Tween<double>(begin: 0.6, end: 1.5).animate(
      CurvedAnimation(parent: _ringController, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _ring2Anim = Tween<double>(begin: 0.6, end: 1.5).animate(
      CurvedAnimation(parent: _ringController, curve: const Interval(0.25, 0.95, curve: Curves.easeOut)),
    );
    _ringOpacity1 = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(parent: _ringController, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _ringOpacity2 = Tween<double>(begin: 0.25, end: 0.0).animate(
      CurvedAnimation(parent: _ringController, curve: const Interval(0.25, 0.95, curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = widget.size;
    final isCompact = logoSize <= 28; // small mode for buttons

    if (isCompact) {
      // Compact mode: just the pulsing logo, no ripple rings
      return AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: _logo(logoSize),
          ),
        ),
      );
    }

    // Full mode: logo + ripple rings
    return SizedBox(
      width: logoSize * 2.2,
      height: logoSize * 2.2,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _ringController]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Ripple ring 2 (offset phase)
              Transform.scale(
                scale: _ring2Anim.value,
                child: Opacity(
                  opacity: _ringOpacity2.value,
                  child: Container(
                    width: logoSize * 1.6,
                    height: logoSize * 1.6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6366F1),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              // Ripple ring 1
              Transform.scale(
                scale: _ring1Anim.value,
                child: Opacity(
                  opacity: _ringOpacity1.value,
                  child: Container(
                    width: logoSize * 1.6,
                    height: logoSize * 1.6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              // Logo with heartbeat scale + glow backing
              Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _opacityAnim.value,
                  child: Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.25 * _scaleAnim.value),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: _logo(logoSize * 0.65),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _logo(double size) {
    return Image.asset(
      'assets/images/agent_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, a, b) => Icon(
        Icons.home_work_rounded,
        size: size * 0.75,
        color: const Color(0xFF6366F1),
      ),
    );
  }
}

/// A full-screen branded loading overlay that sits ON TOP of the current page.
/// Use this for navigation-triggered loads so users never see a blank page.
///
/// Example:
///   if (isLoading) const AppLoadingOverlay()
class AppLoadingOverlay extends StatelessWidget {
  final String? message;
  const AppLoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLoader(size: 64),
              const SizedBox(height: 20),
              Text(
                message ?? 'Please wait...',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
