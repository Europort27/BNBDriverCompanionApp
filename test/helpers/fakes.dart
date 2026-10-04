import 'dart:async';
import 'dart:io';

import 'package:bnbdriverapp/domain/entities/ap_record.dart';
import 'package:bnbdriverapp/domain/entities/discovered_master.dart';
import 'package:bnbdriverapp/domain/entities/geo_position.dart';
import 'package:bnbdriverapp/domain/entities/wardriving_session.dart';
import 'package:bnbdriverapp/domain/repositories/background_service.dart';
import 'package:bnbdriverapp/domain/repositories/history_repository.dart';
import 'package:bnbdriverapp/domain/repositories/location_service.dart';
import 'package:bnbdriverapp/domain/repositories/master_connection.dart';
import 'package:bnbdriverapp/domain/repositories/recording_storage.dart';
import 'package:bnbdriverapp/domain/repositories/settings_repository.dart';
import 'package:bnbdriverapp/domain/repositories/upload_destination.dart';

class FakeSettings implements SettingsRepository {
  String? wdgwarsKey;
  String? wardriftKey;
  bool debug = false;
  String? lastDevice;

  @override
  Future<String?> getWdgwarsApiKey() async => wdgwarsKey;
  @override
  Future<void> setWdgwarsApiKey(String value) async => wdgwarsKey = value;
  @override
  Future<String?> getWardriftApiKey() async => wardriftKey;
  @override
  Future<void> setWardriftApiKey(String value) async => wardriftKey = value;
  @override
  Future<bool> getDebugMode() async => debug;
  @override
  Future<void> setDebugMode(bool value) async => debug = value;
  @override
  Future<String?> getLastDeviceId() async => lastDevice;
  @override
  Future<void> setLastDeviceId(String value) async => lastDevice = value;
}

class FakeHistory implements HistoryRepository {
  final List<WardrivingSession> sessions = [];

  @override
  Future<List<WardrivingSession>> loadAll() async => [...sessions];
  @override
  Future<void> add(WardrivingSession session) async => sessions.add(session);
  @override
  Future<void> update(WardrivingSession session) async {
    for (var i = 0; i < sessions.length; i++) {
      if (sessions[i].fileName == session.fileName) sessions[i] = session;
    }
  }
}

class FakeDestination implements UploadDestination {
  FakeDestination(this.name, {this.error});

  @override
  final String name;
  final Object? error;
  int calls = 0;

  @override
  Future<void> upload(File file, String apiKey) async {
    calls++;
    if (error != null) throw error!;
  }
}

class FakeConnection implements MasterConnection {
  final recordsController = StreamController<ApRecord>.broadcast();
  final disconnectedController = StreamController<void>.broadcast();
  final sentCommands = <MasterCommand>[];
  bool connected = false;
  String? id;

  @override
  Stream<ApRecord> get records => recordsController.stream;
  @override
  Stream<void> get disconnected => disconnectedController.stream;
  @override
  Stream<List<DiscoveredMaster>> get discoveries => const Stream.empty();
  @override
  Stream<bool> get scanning => const Stream.empty();
  @override
  bool get isConnected => connected;
  @override
  String? get connectedId => connected ? id : null;
  @override
  String? get connectedName => connected ? 'BNB-WARDRIVER' : null;
  @override
  Future<bool> isBluetoothOn() async => true;
  @override
  Future<bool> waitForBluetoothOn(Duration timeout) async => true;
  @override
  Future<void> startDiscovery() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(String id) async {
    this.id = id;
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    disconnectedController.add(null);
  }

  @override
  Future<void> sendCommand(MasterCommand command) async {
    if (!connected) throw Exception('Connect to the master node first');
    sentCommands.add(command);
  }
}

class FakeLocation implements LocationService {
  final controller = StreamController<GeoPosition>.broadcast();

  @override
  Stream<GeoPosition> positions() => controller.stream;
  @override
  double distanceBetween(GeoPosition from, GeoPosition to) =>
      (to.latitude - from.latitude).abs() * 111000;
}

class FakeWriter implements RecordingWriter {
  FakeWriter(this.file);

  @override
  final File file;
  final lines = <String>[];
  bool closed = false;

  @override
  void writeln(String line) => lines.add(line);
  @override
  Future<void> close() async => closed = true;
}

class FakeStorage implements RecordingStorage {
  FakeWriter? lastWriter;

  @override
  Future<RecordingWriter> create(DateTime now) async =>
      lastWriter = FakeWriter(File('/tmp/wigle_test.csv'));
  @override
  Future<File?> locate(String fileName, {String? knownPath}) async => null;
}

class FakeBackground implements BackgroundService {
  bool running = false;

  @override
  Future<void> init() async {}
  @override
  Future<void> start(String Function() statusText) async {
    statusText();
    running = true;
  }

  @override
  Future<void> stop() async => running = false;
}
