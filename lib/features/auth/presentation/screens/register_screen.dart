import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';

/// Maps Firebase error codes to friendly messages (same helper as login_screen).
String _friendlyError(String? raw) {
  if (raw == null) return 'Something went wrong. Please try again.';
  final r = raw.toLowerCase();
  if (r.contains('email-already-in-use')) {
    return 'An account already exists with this email. Try logging in instead.';
  }
  if (r.contains('weak-password')) {
    return 'Password must be at least 8 characters.';
  }
  if (r.contains('invalid-email')) {
    return 'Please enter a valid email address.';
  }
  if (r.contains('network-request-failed')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (r.contains('too-many-requests')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  return 'Registration failed. Please check your details and try again.';
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool privacyAccepted = false;
  bool loading = false;
  String selectedRole = 'tenant';
  String? _inlineError;

  late final AnimationController _shakeController = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );
  late final Animation<double> _shakeAnimation = Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut));

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _setError(String? msg) {
    setState(() => _inlineError = msg);
    if (msg != null) _shakeController.forward(from: 0);
  }

  bool _validate() {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty) {
      _setError('Please enter your full name.');
      return false;
    }
    final emailError = Validators.email(email);
    if (emailError != null) {
      _setError('Please enter a valid email address.');
      return false;
    }
    final passwordError = Validators.password(password);
    if (passwordError != null) {
      _setError(passwordError);
      return false;
    }
    if (password.length < 8) {
      _setError('Password must be at least 8 characters.');
      return false;
    }
    if (password != confirmPassword) {
      _setError('Passwords do not match. Please re-check.');
      return false;
    }
    if (!privacyAccepted) {
      _setError('You must accept the Privacy Policy to create an account.');
      return false;
    }
    return true;
  }

  Future<void> _register() async {
    if (!_validate()) return;
    setState(() {
      loading = true;
      _inlineError = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            role: selectedRole,
            privacyAccepted: privacyAccepted,
          );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('just_registered', true);
    } catch (e) {
      if (mounted) _setError(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Surface auth-level errors inline
    if (authState.status == AuthStatus.error &&
        authState.errorMessage != null &&
        _inlineError == null &&
        !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setError(_friendlyError(authState.errorMessage));
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 540 : double.infinity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios),
                      ),
                      const SizedBox(height: 8),
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
                                child: const Icon(Icons.home_rounded, color: Colors.white, size: 45),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Join Agent and explore premium properties',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Form card with shake
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (_, child) {
                          final offset = _inlineError != null
                              ? 8 * (0.5 - (_shakeAnimation.value - 0.5).abs()) * 2
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
                              // Inline error banner
                              if (_inlineError != null)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: Color(0xFFDC2626), size: 20),
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
                                        onTap: () => setState(() => _inlineError = null),
                                        child: const Icon(Icons.close_rounded,
                                            color: Color(0xFFDC2626), size: 16),
                                      ),
                                    ],
                                  ),
                                ),

                              _field(controller: _fullNameController, hint: 'Full Name', icon: Icons.person_outline),
                              const SizedBox(height: 16),
                              _field(controller: _emailController, hint: 'Email Address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 16),

                              // Role selector
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.grey.shade100),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedRole,
                                    isExpanded: true,
                                    borderRadius: BorderRadius.circular(14),
                                    items: [
                                      _roleItem('tenant', Icons.person_rounded, 'Tenant — looking for a property'),
                                      _roleItem('landlord', Icons.home_work_rounded, 'Landlord — listing my property'),
                                    ],
                                    onChanged: (v) => setState(() => selectedRole = v ?? 'tenant'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              _field(
                                controller: _passwordController,
                                hint: 'Password',
                                icon: Icons.lock_outline,
                                obscure: obscurePassword,
                                suffix: IconButton(
                                  onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                  icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade500),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _field(
                                controller: _confirmPasswordController,
                                hint: 'Confirm Password',
                                icon: Icons.lock_outline,
                                obscure: obscureConfirmPassword,
                                suffix: IconButton(
                                  onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                                  icon: Icon(obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade500),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Privacy checkbox
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: privacyAccepted
                                      ? const Color(0xFF6366F1).withValues(alpha: 0.05)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: privacyAccepted
                                        ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: privacyAccepted,
                                      activeColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (v) => setState(() => privacyAccepted = v ?? false),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Wrap(
                                          children: [
                                            const Text('I have read and agree to the ', style: TextStyle(fontSize: 13)),
                                            GestureDetector(
                                              onTap: () => context.push('/privacy'),
                                              child: const Text(
                                                'Privacy Policy',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                            const Text(' and ', style: TextStyle(fontSize: 13)),
                                            GestureDetector(
                                              onTap: () => context.push('/privacy'),
                                              child: const Text(
                                                'Terms of Service',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Register button
                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    elevation: 0,
                                  ),
                                  onPressed: loading ? null : _register,
                                  child: loading || authState.status == AuthStatus.loading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : const Text(
                                          'Create Account',
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey.shade200)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('OR', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey.shade200)),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Google sign-in
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade200),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: () async {
                                    setState(() { loading = true; _inlineError = null; });
                                    try {
                                      await ref.read(authNotifierProvider.notifier).loginWithGoogle();
                                    } catch (e) {
                                      if (mounted) _setError(_friendlyError(e.toString()));
                                    } finally {
                                      if (mounted) setState(() => loading = false);
                                    }
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network('https://cdn-icons-png.flaticon.com/512/2991/2991148.png', height: 22),
                                      const SizedBox(width: 12),
                                      const Text('Continue with Google',
                                          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Already have an account?', style: TextStyle(color: Colors.grey.shade600)),
                                  TextButton(
                                    onPressed: () => context.pop(),
                                    child: const Text('Login', style: TextStyle(fontWeight: FontWeight.bold)),
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
          },
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  DropdownMenuItem<String> _roleItem(String value, IconData icon, String label) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
