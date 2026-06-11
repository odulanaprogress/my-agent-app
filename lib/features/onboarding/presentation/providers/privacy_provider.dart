import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

final privacyProvider = StateNotifierProvider<PrivacyNotifier, bool>(
  (ref) => PrivacyNotifier(),
);

class PrivacyNotifier extends StateNotifier<bool> {
  PrivacyNotifier() : super(false);

  Future<void> acceptPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.privacyAccepted, true);
    state = true;
  }

  Future<bool> checkPrivacyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.privacyAccepted) ?? false;
  }
}
