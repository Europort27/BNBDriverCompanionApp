import 'package:bnbdriverapp/domain/entities/ap_record.dart';
import 'package:bnbdriverapp/domain/entities/geo_position.dart';
import 'package:bnbdriverapp/domain/repositories/master_connection.dart';
import 'package:bnbdriverapp/domain/usecases/upload_recording.dart';
import 'package:bnbdriverapp/presentation/controllers/scanner_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

ApRecord record(String mac, RecordType type, {String node = 'node-1'}) =>
    ApRecord(
      mac: mac,
      ssid: 'ssid',
      rssi: -50,
      channel: 1,
      authMode: 0,
      nodeId: node,
      type: type,
    );

const fix = GeoPosition(latitude: 10, longitude: 20, altitude: 0, accuracy: 3);

void main() {
  late FakeConnection connection;
  late FakeLocation location;
  late FakeStorage storage;
  late FakeBackground background;
  late FakeHistory history;
  late FakeSettings settings;
  late ScannerController controller;

  setUp(() async {
    connection = FakeConnection();
    location = FakeLocation();
    storage = FakeStorage();
    background = FakeBackground();
    history = FakeHistory();
    settings = FakeSettings()..debug = true;
    controller = ScannerController(
      connection: connection,
      location: location,
      storage: storage,
      background: background,
      history: history,
      settings: settings,
      uploadRecording: UploadRecording(
        settings: settings,
        wdgwars: FakeDestination('WDGWars'),
        wardrift: FakeDestination('Wardrift'),
      ),
    );
    await controller.init();
    await controller.connectTo('master-1');
    location.controller.add(fix);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() => controller.dispose());

  void emit(ApRecord r) {
    connection.recordsController.add(r);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('connects and remembers the master', () {
    expect(controller.isConnected, isTrue);
    expect(settings.lastDevice, 'master-1');
  });

  test('counts unique Wi-Fi and Bluetooth devices while recording', () async {
    await controller.startRecording();
    emit(record('aa', RecordType.wifi));
    emit(record('aa', RecordType.wifi));
    emit(record('bb', RecordType.bluetooth));
    emit(record('cc', RecordType.bluetooth));
    await settle();

    expect(controller.wifiCount, 1);
    expect(controller.bluetoothCount, 2);
    expect(controller.nodeStats['node-1']!.uniqueBluetoothIds, {'bb', 'cc'});
    expect(controller.rawTypeCounts, {'WIFI': 2, 'BT': 2});
    expect(storage.lastWriter!.lines, hasLength(2 + 3));
    expect(connection.sentCommands, [MasterCommand.startScan]);
    expect(background.running, isTrue);
  });

  test('tracks nodes but does not record before a GPS fix', () async {
    final noFix = ScannerController(
      connection: connection,
      location: FakeLocation(),
      storage: storage,
      background: background,
      history: history,
      settings: settings,
      uploadRecording: UploadRecording(
        settings: settings,
        wdgwars: FakeDestination('WDGWars'),
        wardrift: FakeDestination('Wardrift'),
      ),
    );
    await noFix.init();
    connection.recordsController.add(record('aa', RecordType.wifi));
    await settle();

    expect(noFix.nodeStats['node-1']!.uniqueWifiBssids, {'aa'});
    expect(noFix.wifiCount, 0);
    noFix.dispose();
  });

  test('stopping saves the session and finalises the file', () async {
    await controller.startRecording();
    emit(record('aa', RecordType.wifi));
    emit(record('bb', RecordType.bluetooth));
    await settle();

    await controller.stopRecording();

    expect(controller.isRecording, isFalse);
    expect(storage.lastWriter!.closed, isTrue);
    expect(background.running, isFalse);
    expect(history.sessions, hasLength(1));
    expect(history.sessions.single.uniqueAccessPoints, 2);
    expect(history.sessions.single.uniqueBluetoothIds, 1);
    expect(history.sessions.single.fileName, 'wigle_test.csv');
  });

  test('can still stop and save after Bluetooth drops', () async {
    await controller.startRecording();
    connection.connected = false;
    connection.disconnectedController.add(null);
    await settle();

    await controller.stopRecording();

    expect(controller.isConnected, isFalse);
    expect(history.sessions, hasLength(1));
  });

  test('reports a dropped link and clears the nodes', () async {
    emit(record('aa', RecordType.wifi));
    await settle();
    expect(controller.nodeStats, isNotEmpty);

    connection.connected = false;
    connection.disconnectedController.add(null);
    await settle();

    expect(controller.isConnected, isFalse);
    expect(controller.nodeStats, isEmpty);
  });

  test('start fails cleanly when not connected', () async {
    await controller.disconnect();
    final messages = <String>[];
    controller.messages.listen(messages.add);

    await controller.startRecording();
    await settle();

    expect(controller.isRecording, isFalse);
    expect(messages.single, contains('Connect to the master node first'));
  });
}
