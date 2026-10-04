import 'package:bnbdriverapp/domain/entities/wardriving_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips through JSON', () {
    const session = WardrivingSession(
      uniqueAccessPoints: 10,
      uniqueBluetoothIds: 3,
      durationSeconds: 90,
      distanceMeters: 1234.5,
      fileName: 'a.csv',
      uploaded: false,
      uploadedToWdgwars: true,
      uploadedToWardrift: false,
      filePath: '/docs/a.csv',
    );

    final copy = WardrivingSession.fromJson(session.toJson());

    expect(copy.fileName, 'a.csv');
    expect(copy.uploadedToWdgwars, isTrue);
    expect(copy.uploadedToWardrift, isFalse);
    expect(copy.filePath, '/docs/a.csv');
  });

  test('reads sessions saved by older versions', () {
    final session = WardrivingSession.fromJson({
      'uniqueAccessPoints': 5,
      'durationSeconds': 60,
      'distanceMeters': 10,
      'fileName': 'old.csv',
      'uploaded': true,
    });

    expect(session.uniqueBluetoothIds, 0);
    expect(session.uploadedToWdgwars, isTrue);
    expect(session.uploadedToWardrift, isTrue);
    expect(session.filePath, isNull);
  });

  test('marks a session uploaded only when both services succeeded', () {
    const session = WardrivingSession(
      uniqueAccessPoints: 1,
      uniqueBluetoothIds: 0,
      durationSeconds: 1,
      distanceMeters: 0,
      fileName: 'a.csv',
      uploaded: false,
      uploadedToWdgwars: false,
      uploadedToWardrift: false,
    );

    final partial = session.withUploadStatus(
      uploadedToWdgwars: true,
      uploadedToWardrift: false,
    );
    final full = partial.withUploadStatus(
      uploadedToWdgwars: true,
      uploadedToWardrift: true,
    );

    expect(partial.uploaded, isFalse);
    expect(full.uploaded, isTrue);
  });
}
