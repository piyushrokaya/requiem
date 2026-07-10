import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Resolves the backend base URL for HTTP calls.
///
/// Defaults to [ApiConfig.baseUrl] (works out of the box for a backend
/// running on the same machine as the emulator/simulator). Can be
/// overridden at runtime — e.g. to point at a LAN IP or a tunnel URL when
/// testing on a physical device — via [setOverrideServerBaseUrl].
class ApiEndpointStore {
  static const String _keyServerBaseUrl = 'server_base_url_override';

  static Future<String> serverBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final override = normalizeServerBaseUrl(prefs.getString(_keyServerBaseUrl));
    return override ?? ApiConfig.baseUrl;
  }

  static Future<void> setOverrideServerBaseUrl(String rawUrl) async {
    final normalized = normalizeServerBaseUrl(rawUrl);
    if (normalized == null) throw ArgumentError('Invalid server URL: $rawUrl');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerBaseUrl, normalized);
  }

  static Future<void> clearOverrideServerBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerBaseUrl);
  }

  /// Normalizes a typed/scanned URL down to `scheme://host[:port]`
  /// (strips any path, query, or fragment).
  static String? normalizeServerBaseUrl(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';

    Uri uri;
    try {
      uri = Uri.parse(withScheme);
    } catch (_) {
      return null;
    }

    if (uri.host.isEmpty) return null;

    final normalizedUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );

    final s = normalizedUri.toString();
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }
}
