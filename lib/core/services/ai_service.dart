import '../network/api_client.dart';
import '../utils/app_exception.dart';

/// AI Service — routes all OpenAI calls through the Cloudflare Workers API.
/// The OpenAI key never touches the Flutter client.
///
/// To enable this, add a /ai/chat endpoint to workers/src/handlers/
/// that forwards the message to OpenAI using the server-side key.
/// Until then, this service throws a clear error rather than exposing the key.
class AIService {
  Future<String> sendMessage(String message) async {
    try {
      // Route through Cloudflare Workers — OpenAI key stays on server
      final res = await ApiClient.workerPost('/ai/chat', {
        'message': message,
      });

      if (res is Map && res['reply'] != null) {
        return res['reply'].toString();
      }

      return res['choices']?.first?['message']?['content']?.toString() ?? '';
    } catch (e) {
      // If the Workers /ai/chat endpoint hasn't been set up yet,
      // return a graceful fallback message rather than crashing.
      throw AppException(
        'AI assistant is temporarily unavailable. Please try again later.',
      );
    }
  }
}
