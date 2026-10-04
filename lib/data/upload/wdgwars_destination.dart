import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/repositories/upload_destination.dart';

/// Uploads a recording to the WDGWars CSV endpoint.
class WdgwarsDestination implements UploadDestination {
  /// Display name used in progress and error messages.
  @override
  String get name => 'WDGWars';

  /// Sends the CSV as multipart form data; throws on a non-2xx response.
  @override
  Future<void> upload(File file, String apiKey) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('https://wdgwars.pl/api/upload-csv'),
          )
          ..headers['X-API-Key'] = apiKey
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send().timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
  }
}
