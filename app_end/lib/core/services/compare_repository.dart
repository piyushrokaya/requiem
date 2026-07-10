import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/comparison_cluster.dart';
import 'api_endpoint_store.dart';

class CompareRepository {
  CompareRepository({String? baseUrl}) : baseUrlOverride = baseUrl;

  final String? baseUrlOverride;

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': '1',
    'User-Agent': 'SanksepApp/1.0',
  };

  Future<List<ComparisonCluster>> fetchClusters() async {
    final base = baseUrlOverride ?? await ApiEndpointStore.serverBaseUrl();
    final uri = _buildUri(base, '/api/compare');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final decoded = _decodeJson(uri, response);
      if (decoded is! List) {
        throw const FormatException('Expected JSON array for /api/compare');
      }
      return decoded
          .map((e) => ComparisonCluster.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    throw Exception(
      'Failed to load clusters: ${response.statusCode} ${response.reasonPhrase ?? ''}',
    );
  }

  static Uri _buildUri(
    String baseUrl,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final trimmed = baseUrl.trim();
    final base = Uri.parse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
    final relative = path.startsWith('/') ? path.substring(1) : path;
    final resolved = base.resolve(relative);
    return queryParameters == null
        ? resolved
        : resolved.replace(queryParameters: queryParameters);
  }

  static dynamic _decodeJson(Uri uri, http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final text = utf8.decode(response.bodyBytes);
    final cleaned = text.startsWith('﻿') ? text.substring(1) : text;

    final trimmed = cleaned.trimLeft();
    final looksLikeHtml =
        trimmed.startsWith('<!DOCTYPE') ||
        trimmed.startsWith('<html') ||
        contentType.contains('text/html');
    if (looksLikeHtml) {
      final snippet = trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
      throw FormatException(
        'Expected JSON but got HTML from $uri (content-type: $contentType). Snippet: $snippet',
      );
    }

    try {
      return jsonDecode(cleaned);
    } on FormatException catch (e) {
      final snippet = trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
      throw FormatException(
        'Invalid JSON from $uri (content-type: $contentType): ${e.message}. Snippet: $snippet',
      );
    }
  }
}
