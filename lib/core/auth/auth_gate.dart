import 'package:flutter/material.dart';

import '../../features/auth/presentation/screens/auth_gate.dart'
    as riverpod_gate;

/// Thin wrapper to avoid duplicate/competing AuthGate implementations.
/// The app router uses the Riverpod-based AuthGate (in features/auth/.../auth_gate.dart).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const riverpod_gate.AuthGate();
  }
}
