import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/ai_config.dart';

class AIService {
  Future<String> sendMessage(String message) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${AIConfig.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4.1-mini',
        'messages': [
          {
            'role': 'system',
            'content': '''
You are AGENT AI assistant.

You help users with:
- finding properties
- payments
- verification
- escrow system
- landlord support
- tenant support

Keep responses short and helpful.
''',
          },
          {'role': 'user', 'content': message},
        ],
      }),
    );

    final data = jsonDecode(response.body);

    return (data['choices']?.first?['message']?['content'] ?? '') as String;
  }
}
