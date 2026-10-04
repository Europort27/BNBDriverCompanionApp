/// Persistent app settings.
abstract class SettingsRepository {
  /// Saved WDGWars API key, if any.
  Future<String?> getWdgwarsApiKey();

  /// Saves the WDGWars API key.
  Future<void> setWdgwarsApiKey(String value);

  /// Saved Wardrift API key, if any.
  Future<String?> getWardriftApiKey();

  /// Saves the Wardrift API key.
  Future<void> setWardriftApiKey(String value);

  /// Whether debug mode (no uploads) is on.
  Future<bool> getDebugMode();

  /// Turns debug mode on or off.
  Future<void> setDebugMode(bool value);

  /// Id of the last connected master, if any.
  Future<String?> getLastDeviceId();

  /// Remembers the last connected master.
  Future<void> setLastDeviceId(String value);
}
