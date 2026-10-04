import 'dart:io';

/// A service that accepts recorded CSV files.
abstract class UploadDestination {
  /// Display name used in progress and error messages.
  String get name;

  /// Uploads [file] using [apiKey]; throws when the upload fails.
  Future<void> upload(File file, String apiKey);
}
