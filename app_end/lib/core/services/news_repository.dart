import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/news_article.dart';
import 'api_endpoint_store.dart';

class NewsRepository {
  NewsRepository({String? baseUrl}) : baseUrlOverride = baseUrl;

  final String? baseUrlOverride;

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': '1',
    'User-Agent': 'SanksepApp/1.0',
  };

  /// Set right after [getTopArticles] resolves. True when the returned list
  /// came from the offline cache because the live fetch failed.
  bool lastFetchWasFromCache = false;

  Future<List<NewsArticle>> getTopArticles({
    int page = 1,
    int limit = 10,
    String? category,
  }) async {
    final cacheKey = _cacheKey(category, page, limit);
    try {
      final base = baseUrlOverride ?? await ApiEndpointStore.serverBaseUrl();
      final uri = _buildUri(
        base,
        '/api/news',
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (category != null && category.trim().isNotEmpty)
            'category': category.trim(),
        },
      );

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final decoded = _decodeJson(uri, response);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object for /api/news');
        }
        final List<dynamic> articlesJson = (decoded['data'] as List?) ?? const [];
        final articles = articlesJson
            .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);

        lastFetchWasFromCache = false;
        unawaited(_saveToCache(cacheKey, articles));
        return articles;
      }

      throw Exception(
        'Failed to load news: ${response.statusCode} ${response.reasonPhrase ?? ''}',
      );
    } catch (err) {
      final cached = await _readFromCache(cacheKey);
      if (cached != null) {
        lastFetchWasFromCache = true;
        return cached;
      }
      rethrow;
    }
  }

  /// Distinct category values currently available (e.g. Politics, Sports).
  Future<List<String>> getCategories() async {
    final base = baseUrlOverride ?? await ApiEndpointStore.serverBaseUrl();
    final uri = _buildUri(base, '/api/news/categories');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final decoded = _decodeJson(uri, response);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Expected JSON object for /api/news/categories',
        );
      }
      final List<dynamic> data = (decoded['data'] as List?) ?? const [];
      return data.map((e) => e.toString()).toList(growable: false);
    }

    throw Exception(
      'Failed to load categories: ${response.statusCode} ${response.reasonPhrase ?? ''}',
    );
  }

  static String _cacheKey(String? category, int page, int limit) {
    final normalizedCategory = (category ?? '').trim().toLowerCase();
    return 'news_cache_${normalizedCategory.isEmpty ? 'all' : normalizedCategory}_${page}_$limit';
  }

  static Future<void> _saveToCache(String key, List<NewsArticle> articles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(articles.map((a) => a.toJson()).toList());
      await prefs.setString(key, encoded);
    } catch (_) {
      // Caching is best-effort; ignore failures (e.g. storage full).
    }
  }

  static Future<List<NewsArticle>?> _readFromCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return null;
    }
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
