// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import '../entities/upload_result.dart';
import '../repositories/settings_repository.dart';
import '../repositories/upload_destination.dart';

/// Receives upload progress so the UI can show it.
abstract class UploadProgressListener {
  /// Called with the services about to be uploaded to.
  void begin(List<String> services);

  /// Called when [service] moves to a new [stage].
  void update(String service, UploadStage stage);

  /// Called once every upload has completed.
  void finish();
}

/// Uploads a recorded CSV to every destination that has an API key set.
class UploadRecording {
  UploadRecording({
    required SettingsRepository settings,
    required UploadDestination wdgwars,
    required UploadDestination wardrift,
    UploadProgressListener? progress,
  }) : _settings = settings,
       _wdgwars = wdgwars,
       _wardrift = wardrift,
       _progress = progress;

  final SettingsRepository _settings;
  final UploadDestination _wdgwars;
  final UploadDestination _wardrift;
  final UploadProgressListener? _progress;

  /// Uploads [file]; does nothing in debug mode or without API keys.
  Future<UploadResult> call(
    File file, {
    bool uploadWdgwars = true,
    bool uploadWardrift = true,
  }) async {
    if (await _settings.getDebugMode()) return UploadResult.none;

    final wdgwarsKey = (await _settings.getWdgwarsApiKey())?.trim() ?? '';
    final wardriftKey = (await _settings.getWardriftApiKey())?.trim() ?? '';
    final doWdgwars = uploadWdgwars && wdgwarsKey.isNotEmpty;
    final doWardrift = uploadWardrift && wardriftKey.isNotEmpty;
    if (!doWdgwars && !doWardrift) return UploadResult.none;

    _progress?.begin([
      if (doWdgwars) _wdgwars.name,
      if (doWardrift) _wardrift.name,
    ]);
    final wdgwarsError = doWdgwars
        ? await _attempt(_wdgwars, file, wdgwarsKey)
        : null;
    final wardriftError = doWardrift
        ? await _attempt(_wardrift, file, wardriftKey)
        : null;
    _progress?.finish();

    return UploadResult(
      uploadedToWdgwars: doWdgwars && wdgwarsError == null,
      uploadedToWardrift: doWardrift && wardriftError == null,
      wdgwarsError: wdgwarsError,
      wardriftError: wardriftError,
    );
  }

  /// Uploads to one destination and returns null on success, otherwise the error text.
  Future<String?> _attempt(
    UploadDestination destination,
    File file,
    String apiKey,
  ) async {
    _progress?.update(destination.name, UploadStage.uploading);
    try {
      await destination.upload(file, apiKey);
      _progress?.update(destination.name, UploadStage.done);
      return null;
    } catch (error) {
      _progress?.update(destination.name, UploadStage.failed);
      return error.toString();
    }
  }
}
