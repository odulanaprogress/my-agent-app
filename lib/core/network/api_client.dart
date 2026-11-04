import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_exception.dart';

class ApiClient {
  /// Primary REST API (Points to live Vercel backend via custom domain)
  static const String baseUrl = 'https://api.agentmobiletech.com/api';

  /// Cloudflare Workers secure API — handles bank resolution, virtual accounts, and edge operations
  static const String workersUrl = 'https://edge.agentmobiletech.com';

  /// Payouts backend (routed through primary backend with verified Flutterwave disbursement)
  static const String railwayUrl = 'https://api.agentmobiletech.com/api';

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

  /// Call the primary REST API.
  static Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.get(uri, headers: headers);
      return _processResponse(response);
    } catch (e) {
      if (e is AppException) rethrow;
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw AppException(msg);
    }
  }

  /// Call the primary REST API.
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
      if (e is AppException) rethrow;
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw AppException(msg);
    }
  }

  /// Call the Cloudflare Workers secure API.
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
      if (e is AppException) rethrow;
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw AppException(msg);
    }
  }

  /// Call the payouts backend (static IP whitelisted on Flutterwave).
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
      if (e is AppException) rethrow;
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw AppException(msg);
    }
  }

  static dynamic _processResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      } else {
        final errorMsg = body['error'] ?? body['message'] ?? 'HTTP Error ${response.statusCode}';
        throw AppException(errorMsg.toString());
      }
    } catch (e) {
      if (e is AppException) rethrow;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
      throw AppException('Server Error (${response.statusCode})');
    }
  }
}
