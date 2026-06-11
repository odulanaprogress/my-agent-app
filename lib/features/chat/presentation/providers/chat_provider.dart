import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});
