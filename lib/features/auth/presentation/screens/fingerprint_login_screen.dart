import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agent_app/core/storage/secure_storage_service.dart';

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

  bool _isRegistrationMode = false;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _isRegistrationMode = FirebaseAuth.instance.currentUser != null;
    _checkBiometrics();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      setState(() {
        _canAuthenticate = isDeviceSupported && canCheckBiometrics;
      });
      if (_canAuthenticate) {
        if (!_isRegistrationMode) {
          _authenticate();
        } else {
          setState(() {
            _statusMessage = 'Enter your password to enable fingerprint login.';
          });
        }
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

  Future<void> _registerFingerprint() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Please enter your password.';
      });
      return;
    }
    setState(() {
      _passwordError = null;
      _isAuthenticating = true;
      _statusMessage = 'Scan your fingerprint to register...';
    });

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to register biometric login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || user.email == null) {
          setState(() {
            _statusMessage = 'No active user found. Please log in first.';
          });
          return;
        }

        setState(() {
          _statusMessage = 'Verifying password...';
        });

        try {
          // Verify password by reauthenticating
          final AuthCredential credential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
          await user.reauthenticateWithCredential(credential);

          // Save credentials securely
          final storage = SecureStorageService();
          await storage.write(key: 'biometric_email', value: user.email!);
          await storage.write(key: 'biometric_password', value: password);

          setState(() {
            _statusMessage = 'Fingerprint login enabled successfully!';
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Fingerprint login enabled successfully!'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              context.pop(); // Go back to dashboard/settings
            }
          }
        } on FirebaseAuthException catch (e) {
          setState(() {
            _statusMessage = 'Incorrect password: ${e.message}';
          });
        } catch (e) {
          setState(() {
            _statusMessage = 'Verification failed: $e';
          });
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
          _statusMessage = 'Authenticated! Retrieving credentials...';
        });

        final storage = SecureStorageService();
        final email = await storage.read('biometric_email');
        final password = await storage.read('biometric_password');

        if (email != null && password != null) {
          setState(() {
            _statusMessage = 'Logging in securely...';
          });

          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );

            setState(() {
              _statusMessage = 'Authenticated! Logging you in...';
            });
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              context.go('/auth');
            }
          } on FirebaseAuthException catch (e) {
            setState(() {
              _statusMessage = 'Firebase Login failed: ${e.message}';
            });
          } catch (e) {
            setState(() {
              _statusMessage = 'Login failed: $e';
            });
          }
        } else {
          setState(() {
            _statusMessage = 'No saved credentials found. Please log in with email/password first.';
          });
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
              Text(
                _isRegistrationMode ? 'Enable Fingerprint' : 'Security Check',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isRegistrationMode
                    ? 'Enter your password to link your biometric credential'
                    : 'Log in with your device biometric credential',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
              
              if (_isRegistrationMode) ...[
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter Account Password',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                    errorText: _passwordError,
                  ),
                ),
              ],
              
              const Spacer(),
              // Fingerprint visual
              GestureDetector(
                onTap: _canAuthenticate
                    ? (_isRegistrationMode ? _registerFingerprint : _authenticate)
                    : null,
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
                    onPressed: _isRegistrationMode ? _registerFingerprint : _authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 20),
                    label: Text(
                      _isRegistrationMode ? 'Enable Fingerprint Login' : 'Scan Fingerprint',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (_isRegistrationMode) {
                    context.pop();
                  } else {
                    context.go('/login');
                  }
                },
                child: Text(
                  _isRegistrationMode ? 'Cancel' : 'Use Email & Password Instead',
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
