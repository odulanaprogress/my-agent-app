import 'package:flutter/material.dart';

import 'profile_screen.dart' as new_impl;

// Kept for potential future rollback.
class ProfileScreenLegacy extends StatelessWidget {
  const ProfileScreenLegacy({super.key});

  @override
  Widget build(BuildContext context) {
    return const new_impl.ProfileScreen();
  }
}
