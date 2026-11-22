import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class StudentApiException implements Exception {
  const StudentApiException(this.message, {this.status});
  final String message;
  final int? status;
}

class StudentApi {
  StudentApi(this.baseUrl);
  final String baseUrl;
  String? token;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(method, path, body: body);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Uint8List> document(String path, String slot) async {
    final response = await _send('GET', path, query: {'slot': slot});
    return response.bodyBytes;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final root = Uri.tryParse(baseUrl);
    final local =
        root != null &&
        const ['localhost', '127.0.0.1', '10.0.2.2'].contains(root.host);
    if (root == null ||
        root.host.isEmpty ||
        root.userInfo.isNotEmpty ||
        root.hasQuery ||
        root.hasFragment ||
        (root.scheme != 'https' &&
            !(kDebugMode && local && root.scheme == 'http'))) {
      throw const StudentApiException(
        'The MotoPass API URL is missing or invalid.',
      );
    }

    final uri = root.replace(
      path: '${root.path.replaceFirst(RegExp(r'/$'), '')}/$path',
      queryParameters: query,
    );
    final request = http.Request(method, uri)..followRedirects = false;
    if (token case final value?) {
      request.headers['Authorization'] = 'Bearer $value';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw StudentApiException(
          data['error'] as String? ??
              'The server could not complete the request.',
          status: response.statusCode,
        );
      }
      return response;
    } on StudentApiException {
      rethrow;
    } catch (_) {
      throw const StudentApiException(
        'Could not reach MotoPass. Please try again.',
      );
    } finally {
      client.close();
    }
  }
}
