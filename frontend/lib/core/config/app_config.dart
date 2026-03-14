import 'dart:io' show Platform;

/// Application configuration for different platforms and environments.
class AppConfig {
  /// Get the base URL for API calls based on the platform.
  ///
  /// Android Emulator: 10.0.2.2:8400 (special gateway IP)
  /// iOS Simulator: localhost:8400 (shares host network)
  /// Physical Device: Update this manually or use environment config
  static String getBaseUrl() {
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to reach host machine
      return 'http://10.0.2.2:8400/api';
    } else if (Platform.isIOS) {
      // iOS simulator uses localhost
      return 'http://localhost:8400/api';
    } else {
      // macOS, Windows, Linux desktop
      return 'http://localhost:8400/api';
    }
  }

  /// API timeout configuration
  static const int connectTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;

  /// Token storage key
  static const String tokenStorageKey = 'auth_token';

  /// Environment name for logging/debugging
  static String getEnvironment() {
    if (Platform.isAndroid) return 'Android Emulator';
    if (Platform.isIOS) return 'iOS Simulator';
    return 'Desktop';
  }
}
