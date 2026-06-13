import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';

/// Maps Firebase error codes to human-friendly messages.
String _friendlyError(String? raw) {
  if (raw == null) return 'Something went wrong. Please try again.';
  final r = raw.toLowerCase();
  if (r.contains('wrong-password') || r.contains('invalid-credential') || r.contains('invalid credential')) {
    return 'Incorrect email or password. Please try again.';
  }
  if (r.contains('user-not-found')) {
    return 'No account found with this email. Try signing up.';
  }
  if (r.contains('user-disabled')) {
    return 'Your account has been suspended. Contact support.';
  }
  if (r.contains('too-many-requests')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (r.contains('network-request-failed')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (r.contains('email-already-in-use')) {
    return 'An account already exists with this email. Try logging in.';
  }
  if (r.contains('weak-password')) {
    return 'Password must be at least 8 characters.';
  }
  if (r.contains('invalid-email')) {
    return 'Please enter a valid email address.';
  }
  return 'Login failed. Please check your details and try again.';
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool obscurePassword = true;
  bool loading = false;
  String? _inlineError;

  // Shake animation
  late final AnimationController _shakeController = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );
  late final Animation<double> _shakeAnimation = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(
    parent: _shakeController,
    curve: Curves.elasticOut,
  ));

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _setError(String? msg) {
    setState(() => _inlineError = msg);
    if (msg != null) _shakeController.forward(from: 0);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _setError('Please enter your email and password.');
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _setError('Please enter a valid email address.');
      return;
    }

    setState(() {
      loading = true;
      _inlineError = null;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .login(email: email, password: password);
    } catch (e) {
      if (!mounted) return;
      _setError(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Show auth errors inline
    final authError = authState.status == AuthStatus.error
        ? authState.errorMessage
        : null;
    if (authError != null && _inlineError == null && !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setError(_friendlyError(authError));
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Logo + brand
              Center(
                child: Column(
                  children: [
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        height: 90,
                        width: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.home_rounded,
                          size: 45,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Agent',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome back — let\'s find your dream property',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Form card with shake
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (_, child) {
                  final offset = _inlineError != null
                      ? 8 *
                          (0.5 -
                              (_shakeAnimation.value - 0.5).abs()) *
                          2
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Inline Error Banner ─────────────────────────
                      if (_inlineError != null)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFDC2626),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _inlineError!,
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _inlineError = null),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Email field ──────────────────────────────
                      _buildField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        hint: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        hasError: _inlineError != null,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),

                      // ── Password field ───────────────────────────
                      _buildField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        obscure: obscurePassword,
                        hasError: _inlineError != null,
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => obscurePassword = !obscurePassword),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),

                      // ── Forgot password ──────────────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                          ),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Login button ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          onPressed:
                              (loading || authState.status == AuthStatus.loading)
                                  ? null
                                  : _login,
                          child: loading ||
                                  authState.status == AuthStatus.loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                              child: Divider(color: Colors.grey.shade200)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12),
                            ),
                          ),
                          Expanded(
                              child: Divider(color: Colors.grey.shade200)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Google ───────────────────────────────────
                      _socialBtn(
                        label: 'Continue with Google',
                        imageUrl:
                            'https://cdn-icons-png.flaticon.com/512/2991/2991148.png',
                        onTap: () async {
                          setState(() {
                            _inlineError = null;
                            loading = true;
                          });
                          try {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .loginWithGoogle();
                          } catch (e) {
                            if (mounted) {
                              _setError(_friendlyError(e.toString()));
                            }
                          } finally {
                            if (mounted) setState(() => loading = false);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── Biometrics ───────────────────────────────
                      _outlinedBtn(
                        label: 'Continue with Biometrics',
                        icon: Icons.fingerprint_rounded,
                        iconColor: const Color(0xFF6366F1),
                        onTap: () => context.push('/fingerprint'),
                      ),
                      const SizedBox(height: 28),

                      // ── Sign up link ─────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: const Text(
                              'Register',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool hasError = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction:
          suffixIcon != null ? TextInputAction.done : TextInputAction.next,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(
          icon,
          color: hasError ? const Color(0xFFDC2626) : Colors.grey.shade500,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: hasError
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: hasError
                ? const Color(0xFFFCA5A5)
                : Colors.grey.shade100,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: hasError
                ? const Color(0xFFDC2626)
                : AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _socialBtn({
    required String label,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade200),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(imageUrl, height: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlinedBtn({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade200),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
        ),
        onPressed: onTap,
        icon: Icon(icon, color: iconColor, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
