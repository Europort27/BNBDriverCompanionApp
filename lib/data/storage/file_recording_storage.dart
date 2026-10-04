import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/repositories/recording_storage.dart';
import '../../domain/wigle_csv.dart';

/// Appends lines to a CSV file through an [IOSink].
class _FileRecordingWriter implements RecordingWriter {
  _FileRecordingWriter(this.file)
    : _sink = file.openWrite(mode: FileMode.write);

  @override
  final File file;
  final IOSink _sink;

  /// Queues a line for writing.
  @override
  void writeln(String line) => _sink.writeln(line);

  /// Flushes and closes the file.
  @override
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}

/// Stores recordings as WiGLE CSV files in the Documents folder.
class FileRecordingStorage implements RecordingStorage {
  static const _documentsPath = '/storage/emulated/0/Documents';

  /// Creates a new timestamped CSV in a writable directory.
  @override
  Future<RecordingWriter> create(DateTime now) async {
    final directory = await _resolveDirectory();
    return _FileRecordingWriter(
      File('${directory.path}/${WigleCsv.fileName(now)}'),
    );
  }

  /// Requests storage permissions and falls back to app-private external storage.
  Future<Directory> _resolveDirectory() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    try {
      final documentsDir = Directory(_documentsPath);
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      return documentsDir;
    } catch (_) {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('No writable storage directory available');
      }
      return directory;
    }
  }

  /// Finds a recorded CSV by its saved path or in the known folders.
  @override
  Future<File?> locate(String fileName, {String? knownPath}) async {
    final candidates = <String>[?knownPath, '$_documentsPath/$fileName'];
    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) candidates.add('${externalDir.path}/$fileName');
    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) return file;
    }
    return null;
  }
}
