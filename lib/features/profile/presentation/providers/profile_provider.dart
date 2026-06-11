import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_app/features/auth/presentation/providers/auth_provider.dart';

import '../../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

/// Real-time user profile.
///
/// Reads from `users/{uid}`.
final profileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    return const Stream<Map<String, dynamic>?>.empty();
  }
  return ref.watch(profileRepositoryProvider).watchProfileMap(uid);
});
