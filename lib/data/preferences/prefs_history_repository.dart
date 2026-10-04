import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/wardriving_session.dart';
import '../../domain/repositories/history_repository.dart';

/// Stores session history as JSON strings in SharedPreferences.
class PrefsHistoryRepository implements HistoryRepository {
  static const _key = 'wardriving_history';

  /// Reads all sessions oldest first, skipping unreadable entries.
  @override
  Future<List<WardrivingSession>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = <WardrivingSession>[];
    for (final stored in prefs.getStringList(_key) ?? const <String>[]) {
      try {
        sessions.add(
          WardrivingSession.fromJson(
            jsonDecode(stored) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Ignore malformed entries from an older app version.
      }
    }
    return sessions;
  }

  /// Appends a session to the stored history.
  @override
  Future<void> add(WardrivingSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? <String>[];
    stored.add(jsonEncode(session.toJson()));
    await prefs.setStringList(_key, stored);
  }

  /// Rewrites stored sessions whose file name matches [session].
  @override
  Future<void> update(WardrivingSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = [...(prefs.getStringList(_key) ?? const <String>[])];
    for (var i = 0; i < stored.length; i++) {
      try {
        final json = jsonDecode(stored[i]) as Map<String, dynamic>;
        if (json['fileName'] == session.fileName) {
          stored[i] = jsonEncode(session.toJson());
        }
      } catch (_) {
        // Skip malformed entries.
      }
    }
    await prefs.setStringList(_key, stored);
  }
}
