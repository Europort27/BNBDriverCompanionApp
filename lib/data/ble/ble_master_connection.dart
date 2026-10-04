import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/entities/ap_record.dart';
import '../../domain/entities/discovered_master.dart';
import '../../domain/repositories/master_connection.dart';
import 'ap_record_codec.dart';

// GATT UUIDs exposed by the master_node firmware. NimBLE stores the UUID
// bytes little-endian, so these are the canonical client-facing strings.
final Guid _serviceUuid = Guid('88776655-4433-2211-ffee-ddccbbaa0001');
final Guid _apStreamUuid = Guid('88776655-4433-2211-ffee-ddccbbaa0002');
final Guid _controlUuid = Guid('88776655-4433-2211-ffee-ddccbbaa0003');

/// flutter_blue_plus implementation of [MasterConnection] for the BNB-WarDriver master.
class BleMasterConnection implements MasterConnection {
  final _records = StreamController<ApRecord>.broadcast();
  final _disconnected = StreamController<void>.broadcast();
  final _discoveries = StreamController<List<DiscoveredMaster>>.broadcast();
  final List<int> _buffer = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _control;
  bool _connected = false;
  StreamSubscription<BluetoothConnectionState>? _stateSub;
  StreamSubscription<List<int>>? _valueSub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  /// Decoded Wi-Fi/Bluetooth records streamed by the master.
  @override
  Stream<ApRecord> get records => _records.stream;

  /// Fires when the BLE link drops.
  @override
  Stream<void> get disconnected => _disconnected.stream;

  /// Masters found during the current scan.
  @override
  Stream<List<DiscoveredMaster>> get discoveries => _discoveries.stream;

  /// Whether a BLE scan is running.
  @override
  Stream<bool> get scanning => FlutterBluePlus.isScanning;

  /// True once connected and subscribed to the AP stream.
  @override
  bool get isConnected => _connected;

  /// Remote id of the connected master, or null.
  @override
  String? get connectedId => _connected ? _device?.remoteId.str : null;

  /// Advertised name of the connected master, or null.
  @override
  String? get connectedName => _connected ? _device?.platformName : null;

  /// True if the Bluetooth adapter is on (always true off Android).
  @override
  Future<bool> isBluetoothOn() async {
    if (!Platform.isAndroid) return true;
    return await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
  }

  /// Waits up to [timeout] for the adapter to turn on.
  @override
  Future<bool> waitForBluetoothOn(Duration timeout) async {
    try {
      await FlutterBluePlus.adapterState
          .firstWhere((state) => state == BluetoothAdapterState.on)
          .timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Matches devices advertising the master name or GATT service.
  bool _isMaster(ScanResult result) =>
      result.advertisementData.advName.toUpperCase().contains(
        'BNB-WARDRIVER',
      ) ||
      result.advertisementData.serviceUuids.contains(_serviceUuid);

  /// Starts a 10 second scan and publishes matching masters.
  @override
  Future<void> startDiscovery() async {
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      _discoveries.add([
        for (final result in results.where(_isMaster))
          DiscoveredMaster(
            id: result.device.remoteId.str,
            name: result.advertisementData.advName,
            rssi: result.rssi,
          ),
      ]);
    });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  /// Stops the running scan.
  @override
  Future<void> stopDiscovery() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connects to [id], subscribes to the AP stream and tracks link drops.
  @override
  Future<void> connect(String id) async {
    final device = BluetoothDevice.fromId(id);

    await _stateSub?.cancel();
    _stateSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _connected = false;
        _disconnected.add(null);
      }
    });

    await device.connect(timeout: const Duration(seconds: 10));
    await _subscribe(device);
    _device = device;
    _connected = true;
  }

  /// Finds the master GATT service and subscribes to its AP record notifications.
  Future<void> _subscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final service = services.firstWhere(
      (candidate) => candidate.uuid == _serviceUuid,
      orElse: () => throw Exception('Master GATT service not found'),
    );
    final stream = service.characteristics.firstWhere(
      (c) => c.uuid == _apStreamUuid,
      orElse: () =>
          throw Exception('Master AP stream characteristic not found'),
    );
    final control = service.characteristics.firstWhere(
      (c) => c.uuid == _controlUuid,
      orElse: () => throw Exception('Master control characteristic not found'),
    );

    await stream.setNotifyValue(true);
    await _valueSub?.cancel();
    _control = control;
    _buffer.clear();
    _valueSub = stream.lastValueStream.listen((value) {
      _buffer.addAll(value);
      while (_buffer.length >= ApRecordCodec.recordLength) {
        final bytes = _buffer.sublist(0, ApRecordCodec.recordLength);
        _buffer.removeRange(0, ApRecordCodec.recordLength);
        _records.add(ApRecordCodec.decode(bytes));
      }
    });
  }

  /// Drops the BLE link and clears buffered data.
  @override
  Future<void> disconnect() async {
    await _valueSub?.cancel();
    await _device?.disconnect();
    _control = null;
    _buffer.clear();
    _connected = false;
  }

  /// Writes a scan command to the control characteristic; throws if not connected.
  @override
  Future<void> sendCommand(MasterCommand command) async {
    final control = _control;
    if (control == null || !_connected) {
      throw Exception('Connect to the master node first');
    }
    await control.write(
      [command.code],
      withoutResponse:
          control.properties.writeWithoutResponse && !control.properties.write,
    );
  }
}
