import 'package:bnbdriverapp/data/preferences/prefs_history_repository.dart';
import 'package:bnbdriverapp/domain/entities/wardriving_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WardrivingSession session(String name, {bool wardrift = false}) =>
    WardrivingSession(
      uniqueAccessPoints: 1,
      uniqueBluetoothIds: 0,
      durationSeconds: 1,
      distanceMeters: 0,
      fileName: name,
      uploaded: false,
      uploadedToWdgwars: false,
      uploadedToWardrift: wardrift,
    );

void main() {
  late PrefsHistoryRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = PrefsHistoryRepository();
  });

  test('stores sessions oldest first', () async {
    await repository.add(session('a.csv'));
    await repository.add(session('b.csv'));

    final names = (await repository.loadAll()).map((s) => s.fileName);
    expect(names, ['a.csv', 'b.csv']);
  });

  test('updates only the matching session', () async {
    await repository.add(session('a.csv'));
    await repository.add(session('b.csv'));

    await repository.update(session('b.csv', wardrift: true));

    final all = await repository.loadAll();
    expect(all[0].uploadedToWardrift, isFalse);
    expect(all[1].uploadedToWardrift, isTrue);
  });

  test('skips malformed entries', () async {
    SharedPreferences.setMockInitialValues({
      'wardriving_history': ['not json'],
    });

    expect(await repository.loadAll(), isEmpty);
  });
}
