import 'package:flutter/foundation.dart';

import '../../domain/repositories/settings_repository.dart';

/// Holds API keys and the debug-mode flag for the Settings screen.
class SettingsController extends ChangeNotifier {
  SettingsController(this._settings);

  final SettingsRepository _settings;

  String wdgwarsApiKey = '';
  String wardriftApiKey = '';
  bool debugMode = false;
  bool isSavingWdgwars = false;
  bool isSavingWardrift = false;

  /// Reads all settings from storage.
  Future<void> load() async {
    wdgwarsApiKey = await _settings.getWdgwarsApiKey() ?? '';
    wardriftApiKey = await _settings.getWardriftApiKey() ?? '';
    debugMode = await _settings.getDebugMode();
    notifyListeners();
  }

  /// Trims and saves the WDGWars API key.
  Future<void> saveWdgwarsApiKey(String value) async {
    isSavingWdgwars = true;
    notifyListeners();
    wdgwarsApiKey = value.trim();
    await _settings.setWdgwarsApiKey(wdgwarsApiKey);
    isSavingWdgwars = false;
    notifyListeners();
  }

  /// Trims and saves the Wardrift API key.
  Future<void> saveWardriftApiKey(String value) async {
    isSavingWardrift = true;
    notifyListeners();
    wardriftApiKey = value.trim();
    await _settings.setWardriftApiKey(wardriftApiKey);
    isSavingWardrift = false;
    notifyListeners();
  }

  /// Updates debug mode immediately, then persists it.
  Future<void> setDebugMode(bool value) async {
    debugMode = value;
    notifyListeners();
    await _settings.setDebugMode(value);
  }
}
