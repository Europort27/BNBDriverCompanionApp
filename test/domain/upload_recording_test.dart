import 'dart:io';

import 'package:bnbdriverapp/domain/entities/upload_result.dart';
import 'package:bnbdriverapp/domain/usecases/upload_recording.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

class _RecordingProgress implements UploadProgressListener {
  final events = <String>[];

  @override
  void begin(List<String> services) =>
      events.add('begin ${services.join(',')}');
  @override
  void update(String service, UploadStage stage) =>
      events.add('$service ${stage.name}');
  @override
  void finish() => events.add('finish');
}

void main() {
  final file = File('/tmp/x.csv');
  late FakeSettings settings;
  late FakeDestination wdgwars;
  late FakeDestination wardrift;
  late _RecordingProgress progress;

  UploadRecording build() => UploadRecording(
    settings: settings,
    wdgwars: wdgwars,
    wardrift: wardrift,
    progress: progress,
  );

  setUp(() {
    settings = FakeSettings()
      ..wdgwarsKey = ' key1 '
      ..wardriftKey = 'key2';
    wdgwars = FakeDestination('WDGWars');
    wardrift = FakeDestination('Wardrift');
    progress = _RecordingProgress();
  });

  test('uploads to every destination that has a key', () async {
    final result = await build()(file);

    expect(result.uploadedToWdgwars, isTrue);
    expect(result.uploadedToWardrift, isTrue);
    expect(progress.events, [
      'begin WDGWars,Wardrift',
      'WDGWars uploading',
      'WDGWars done',
      'Wardrift uploading',
      'Wardrift done',
      'finish',
    ]);
  });

  test('skips destinations without a key', () async {
    settings.wardriftKey = '  ';

    final result = await build()(file);

    expect(wardrift.calls, 0);
    expect(result.uploadedToWardrift, isFalse);
    expect(result.wardriftError, isNull);
    expect(progress.events.first, 'begin WDGWars');
  });

  test('reports a failure without stopping the other upload', () async {
    wdgwars = FakeDestination('WDGWars', error: Exception('HTTP 500'));

    final result = await build()(file);

    expect(result.uploadedToWdgwars, isFalse);
    expect(result.wdgwarsError, contains('HTTP 500'));
    expect(result.uploadedToWardrift, isTrue);
    expect(progress.events, contains('WDGWars failed'));
  });

  test('only retries the requested destination', () async {
    await build()(file, uploadWdgwars: false);

    expect(wdgwars.calls, 0);
    expect(wardrift.calls, 1);
  });

  test('does nothing in debug mode', () async {
    settings.debug = true;

    final result = await build()(file);

    expect(wdgwars.calls + wardrift.calls, 0);
    expect(result.uploadedToWdgwars, isFalse);
    expect(progress.events, isEmpty);
  });
}
