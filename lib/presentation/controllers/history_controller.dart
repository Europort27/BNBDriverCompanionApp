// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../domain/entities/wardriving_session.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/recording_storage.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/upload_recording.dart';

/// Loads finished sessions and retries failed uploads.
class HistoryController extends ChangeNotifier {
  HistoryController({
    required HistoryRepository history,
    required SettingsRepository settings,
    required RecordingStorage storage,
    required UploadRecording uploadRecording,
  }) : _history = history,
       _settings = settings,
       _storage = storage,
       _uploadRecording = uploadRecording;

  final HistoryRepository _history;
  final SettingsRepository _settings;
  final RecordingStorage _storage;
  final UploadRecording _uploadRecording;

  List<WardrivingSession> sessions = [];
  bool isLoading = true;
  bool showWdgwars = false;
  bool showWardrift = false;
  final Set<String> _retrying = {};

  /// True while [fileName] is being re-uploaded.
  bool isRetrying(String fileName) => _retrying.contains(fileName);

  /// Reloads sessions (newest first) and which upload services are configured.
  Future<void> load() async {
    sessions = (await _history.loadAll()).reversed.toList();
    showWdgwars =
        (await _settings.getWdgwarsApiKey())?.trim().isNotEmpty ?? false;
    showWardrift =
        (await _settings.getWardriftApiKey())?.trim().isNotEmpty ?? false;
    isLoading = false;
    notifyListeners();
  }

  /// Re-uploads [session] to the chosen services and returns a message to show, or null if already running.
  Future<String?> resubmit(
    WardrivingSession session, {
    required bool wdgwars,
    required bool wardrift,
  }) async {
    if (isRetrying(session.fileName)) return null;
    if (await _settings.getDebugMode()) return 'Debug mode: upload skipped';

    _retrying.add(session.fileName);
    notifyListeners();
    try {
      final file = await _storage.locate(
        session.fileName,
        knownPath: session.filePath,
      );
      if (file == null) return 'CSV file not found on this device';

      final result = await _uploadRecording(
        file,
        uploadWdgwars: wdgwars,
        uploadWardrift: wardrift,
      );
      await _history.update(
        session.withUploadStatus(
          uploadedToWdgwars:
              session.uploadedToWdgwars || result.uploadedToWdgwars,
          uploadedToWardrift:
              session.uploadedToWardrift || result.uploadedToWardrift,
          filePath: file.path,
        ),
      );

      await load();
      final failures = <String>[
        if (result.wdgwarsError != null) 'WDGWars: ${result.wdgwarsError}',
        if (result.wardriftError != null) 'Wardrift: ${result.wardriftError}',
      ];
      return failures.isEmpty
          ? 'Upload succeeded'
          : 'Upload failed: ${failures.join('; ')}';
    } finally {
      _retrying.remove(session.fileName);
      notifyListeners();
    }
  }
}
