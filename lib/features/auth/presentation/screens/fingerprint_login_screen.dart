import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

class FingerprintLoginScreen extends StatefulWidget {
  const FingerprintLoginScreen({super.key});

  @override
  State<FingerprintLoginScreen> createState() => _FingerprintLoginScreenState();
}

class _FingerprintLoginScreenState extends State<FingerprintLoginScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _canAuthenticate = false;
  String _statusMessage = 'Awaiting fingerprint scan...';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      setState(() {
        _canAuthenticate = isDeviceSupported && canCheckBiometrics;
      });
      if (_canAuthenticate) {
        _authenticate();
      } else {
        setState(() {
          _statusMessage = 'Biometric authentication is not supported or set up on this device.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking biometrics: $e';
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Scanning fingerprint...';
    });

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to log into AGENT securely',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        setState(() {
          _statusMessage = 'Authenticated! Logging you in...';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          context.go('/auth');
        }
      } else {
        setState(() {
          _statusMessage = 'Authentication failed. Please try again.';
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = 'Error during biometric scan: ${e.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium dark background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Security shield/icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF6366F1),
                  size: 42,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Security Check',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Log in with your device biometric credential',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // Fingerprint visual
              GestureDetector(
                onTap: _canAuthenticate ? _authenticate : null,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _isAuthenticating
                            ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                            : const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        boxShadow: _isAuthenticating
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: _canAuthenticate ? const Color(0xFF6366F1) : Colors.grey.shade600,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _canAuthenticate ? Colors.white70 : Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_canAuthenticate)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 20),
                    label: const Text(
                      'Scan Fingerprint',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  'Use Email & Password Instead',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
