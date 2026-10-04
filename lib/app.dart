import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/background/foreground_background_service.dart';
import 'data/ble/ble_master_connection.dart';
import 'data/location/geolocator_location_service.dart';
import 'data/preferences/prefs_history_repository.dart';
import 'data/preferences/prefs_settings_repository.dart';
import 'data/storage/file_recording_storage.dart';
import 'data/upload/wardrift_destination.dart';
import 'data/upload/wdgwars_destination.dart';
import 'domain/usecases/upload_recording.dart';
import 'presentation/app_shell.dart';
import 'presentation/controllers/history_controller.dart';
import 'presentation/controllers/scanner_controller.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/controllers/upload_progress_controller.dart';

/// Composition root: builds every repository, use case and controller once.
class AppDependencies {
  AppDependencies._({
    required this.scanner,
    required this.history,
    required this.settings,
    required this.uploadProgress,
  });

  /// Wires the data-layer implementations into the controllers.
  factory AppDependencies.create() {
    final settingsRepository = PrefsSettingsRepository();
    final historyRepository = PrefsHistoryRepository();
    final storage = FileRecordingStorage();
    final uploadProgress = UploadProgressController();
    final uploadRecording = UploadRecording(
      settings: settingsRepository,
      wdgwars: WdgwarsDestination(),
      wardrift: WardriftDestination(),
      progress: uploadProgress,
    );

    return AppDependencies._(
      uploadProgress: uploadProgress,
      settings: SettingsController(settingsRepository),
      history: HistoryController(
        history: historyRepository,
        settings: settingsRepository,
        storage: storage,
        uploadRecording: uploadRecording,
      ),
      scanner: ScannerController(
        connection: BleMasterConnection(),
        location: GeolocatorLocationService(),
        storage: storage,
        background: ForegroundBackgroundService(),
        uploadRecording: uploadRecording,
        history: historyRepository,
        settings: settingsRepository,
      ),
    );
  }

  final ScannerController scanner;
  final HistoryController history;
  final SettingsController settings;
  final UploadProgressController uploadProgress;
}

/// Root widget: applies the neon theme and shows the tab shell.
class BnbDriverApp extends StatelessWidget {
  const BnbDriverApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  /// Builds the MaterialApp.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: AppShell(
        scanner: dependencies.scanner,
        history: dependencies.history,
        settings: dependencies.settings,
        uploadProgress: dependencies.uploadProgress,
      ),
    );
  }
}
