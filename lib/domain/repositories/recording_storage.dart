import 'dart:io';

/// An open recording file that lines can be appended to.
abstract class RecordingWriter {
  /// The file being written.
  File get file;

  /// Appends one line.
  void writeln(String line);

  /// Flushes and closes the file.
  Future<void> close();
}

/// Creates and finds recording files.
abstract class RecordingStorage {
  /// Opens a new recording file named for [now].
  Future<RecordingWriter> create(DateTime now);

  /// Finds a previously recorded CSV, or null when it no longer exists.
  Future<File?> locate(String fileName, {String? knownPath});
}
