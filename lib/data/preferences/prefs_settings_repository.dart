import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/settings_repository.dart';

/// SharedPreferences-backed settings.
class PrefsSettingsRepository implements SettingsRepository {
  static const _wdgwarsKey = 'wdgwars_api_key';
  static const _wardriftKey = 'wardrift_api_key';
  static const _debugKey = 'debug_mode';
  static const _lastDeviceKey = 'last_device_id';

  /// The shared preferences instance.
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Reads the saved WDGWars API key.
  @override
  Future<String?> getWdgwarsApiKey() async =>
      (await _prefs).getString(_wdgwarsKey);

  /// Saves the WDGWars API key.
  @override
  Future<void> setWdgwarsApiKey(String value) async =>
      (await _prefs).setString(_wdgwarsKey, value);

  /// Reads the saved Wardrift API key.
  @override
  Future<String?> getWardriftApiKey() async =>
      (await _prefs).getString(_wardriftKey);

  /// Saves the Wardrift API key.
  @override
  Future<void> setWardriftApiKey(String value) async =>
      (await _prefs).setString(_wardriftKey, value);

  /// Reads the debug-mode flag (false by default).
  @override
  Future<bool> getDebugMode() async =>
      (await _prefs).getBool(_debugKey) ?? false;

  /// Saves the debug-mode flag.
  @override
  Future<void> setDebugMode(bool value) async =>
      (await _prefs).setBool(_debugKey, value);

  /// Reads the id of the last connected master.
  @override
  Future<String?> getLastDeviceId() async =>
      (await _prefs).getString(_lastDeviceKey);

  /// Saves the id of the last connected master.
  @override
  Future<void> setLastDeviceId(String value) async =>
      (await _prefs).setString(_lastDeviceKey, value);
}
