import 'package:flutter/foundation.dart';

/// Default backend location, used when no runtime override has been set
/// via [ApiEndpointStore]. Points at a backend running on the same
/// developer machine as the emulator/simulator.
class ApiConfig {
  static const int port = 5000;

  /// Override host at build/run time, e.g.
  /// `flutter run --dart-define=API_HOST=192.168.1.50`
  static const String _hostOverride = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get host {
    if (_hostOverride.isNotEmpty) return _hostOverride;

    if (kIsWeb) return 'localhost';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator -> host machine.
        return '10.0.2.2';
      default:
        // iOS simulator / Windows / macOS / Linux.
        return 'localhost';
    }
  }

  static String get baseUrl => 'http://$host:$port';

  static String get newsBaseUrl => '$baseUrl/api/news';
  static String get compareBaseUrl => '$baseUrl/api/compare';
}
