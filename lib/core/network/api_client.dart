import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  /// Express backend URL (Points to Railway backend which is fully configured)
  static const String baseUrl = 'https://my-agent-app-production-36d3.up.railway.app/api';

  /// Cloudflare Workers secure API — handles AI and other calls
  static const String workersUrl = 'https://agent-api.odulanaprogress.workers.dev';

  /// Railway backend — static IP whitelisted on Flutterwave, handles all withdrawals
  static const String railwayUrl = 'https://my-agent-app-production-36d3.up.railway.app/api';

  static Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    String? token;
    if (user != null) {
      token = await user.getIdToken();
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Only the verified Firebase ID token is sent — never a raw uid header.
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Call the local Express backend (dev only).
  static Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.get(uri, headers: headers);
      return _processResponse(response);
    } catch (e) {
      throw Exception('API Network Request Failed: $e');
    }
  }

  /// Call the local Express backend (dev only).
  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('API Network Request Failed: $e');
    }
  }

  /// Call the Cloudflare Workers secure API.
  /// Use this for AI and non-Flutterwave operations.
  static Future<dynamic> workerPost(String path, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$workersUrl$path');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Workers API Request Failed: $e');
    }
  }

  /// Call the Railway backend (static IP whitelisted on Flutterwave).
  /// Use this for all withdrawal/payout operations.
  static Future<dynamic> railwayPost(String path, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$railwayUrl$path');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Workers API Request Failed: $e');
    }
  }

  static dynamic _processResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      final errorMsg = body['error'] ?? body['message'] ?? 'HTTP Error ${response.statusCode}';
      throw Exception(errorMsg);
    }
  }
}
