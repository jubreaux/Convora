/// Application configuration constants.
class AppConfig {
  /// API timeout configuration
  static const int connectTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;

  /// Token storage key
  static const String tokenStorageKey = 'auth_token';

  /// SharedPreferences key for persisted server URL
  static const String serverUrlKey = 'server_url';
}
