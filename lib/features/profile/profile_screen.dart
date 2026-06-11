import 'package:flutter/material.dart';

import 'presentation/screens/profile_screen.dart' as presentation;

/// Compatibility wrapper.
///
/// Your app currently imports `lib/features/profile/profile_screen.dart` in some places.
/// To ensure the upgraded Riverpod profile UI is shown everywhere, we forward
/// to the new implementation.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const presentation.ProfileScreen();
  }
}
