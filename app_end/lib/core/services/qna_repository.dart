import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_endpoint_store.dart';

/// One answer returned by the QnA (RAG) backend.
class QnaAnswer {
  const QnaAnswer({required this.answer, required this.sources});

  final String answer;
  final List<String> sources;

  factory QnaAnswer.fromJson(Map<String, dynamic> json) {
    final rawSources = (json['sources'] as List?) ?? const [];
    return QnaAnswer(
      answer: (json['answer'] as String? ?? '').trim(),
      sources: rawSources
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList(growable: false),
    );
  }
}

/// Talks to `POST /api/qna/ask` — the Retrieval-Augmented QnA endpoint that
/// answers Nepali questions from the news database (via Gemini).
class QnaRepository {
  QnaRepository({String? baseUrl}) : baseUrlOverride = baseUrl;

  final String? baseUrlOverride;

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': '1',
    'User-Agent': 'SanksepApp/1.0',
  };

  /// Asks a question. [clusterId] scopes retrieval to a single compare-cluster
  /// when the user is asking about one specific story (else searches all news).
  Future<QnaAnswer> ask(String question, {int? clusterId}) async {
    final base = baseUrlOverride ?? await ApiEndpointStore.serverBaseUrl();
    final uri = _buildUri(base, '/api/qna/ask');

    final payload = <String, dynamic>{'question': question};
    if (clusterId != null) payload['cluster_id'] = clusterId;
    final body = jsonEncode(payload);

    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      final decoded = _decodeJson(uri, response);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object for /api/qna/ask');
      }
      return QnaAnswer.fromJson(decoded);
    }

    throw Exception(
      'Failed to get answer: ${response.statusCode} ${response.reasonPhrase ?? ''}',
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
