import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/secure_storage_service.dart';

/// Shows a bottom-sheet prompting the user to register their fingerprint
/// if they haven't done so yet (i.e. no biometric credentials in SecureStorage).
///
/// Returns true if the user has credentials already (no prompt needed).
/// Call this before logout or after successful registration.
/// Returns true if the flow should proceed (e.g. user skipped, or is already registered).
/// Returns false if the user clicked "Register Fingerprint" (aborting the current flow to register).
Future<bool> showBiometricRegistrationPromptIfNeeded(
  BuildContext context,
) async {
  final storage = SecureStorageService();
  final email = await storage.read('biometric_email');

  if (email != null && email.isNotEmpty) return true; // already registered

  if (!context.mounted) return true;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BiometricRegistrationSheet(),
  );

  if (result == false) return false;
  return true;
}

class _BiometricRegistrationSheet extends StatelessWidget {
  const _BiometricRegistrationSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Fingerprint icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              color: Color(0xFF6366F1),
              size: 42,
            ),
          ),
          const SizedBox(height: 22),

          const Text(
            'Enable Fingerprint Login',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Text(
            'Set up biometric login for faster, more secure access. Your fingerprint credentials are stored securely on your device only.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Security badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, color: Colors.green, size: 14),
                SizedBox(width: 6),
                Text(
                  'Stored locally — never shared',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Register button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, false);
                context.push('/fingerprint');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon:
                  const Icon(Icons.fingerprint_rounded, size: 22),
              label: const Text(
                'Register Fingerprint',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Skip
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white60,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Skip for Now',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
