import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  /// Express backend URL (always points to deployed Vercel backend)
  static const String baseUrl = 'https://my-agent-app-backend.vercel.app/api';

  /// Cloudflare Workers secure API — handles all Flutterwave calls
  static const String workersUrl = 'https://agent-api.odulanaprogress.workers.dev';

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
  /// Use this for all Flutterwave-related operations.
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
