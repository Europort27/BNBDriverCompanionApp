import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../domain/repositories/upload_destination.dart';

/// Uploads a recording to the Wardrift ingest API.
class WardriftDestination implements UploadDestination {
  /// Display name used in progress and error messages.
  @override
  String get name => 'Wardrift';

  /// POSTs the CSV with a fresh idempotency key; throws on a non-2xx response.
  @override
  Future<void> upload(File file, String apiKey) async {
    final idempotencyKey = newIdempotencyKey();
    final baseName = file.uri.pathSegments.last.replaceFirst(
      RegExp(r'\.csv$', caseSensitive: false),
      '',
    );
    final response = await http
        .post(
          Uri.parse('https://wardrift.net/v1/ingest/signals'),
          headers: {
            'X-API-Key': apiKey,
            'Content-Type': 'text/csv',
            'X-File-Name': '${baseName}_${idempotencyKey.substring(0, 8)}.csv',
            'Idempotency-Key': idempotencyKey,
          },
          body: await file.readAsBytes(),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = response.body.trim();
      throw Exception(
        'HTTP ${response.statusCode}${errorBody.isEmpty ? '' : ': $errorBody'}',
      );
    }
  }

  /// Random UUID v4, regenerated per attempt so re-uploads are never rejected.
  static String newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
