// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/format.dart';
import '../../domain/entities/ap_record.dart';
import '../../domain/entities/discovered_master.dart';
import '../../domain/entities/geo_position.dart';
import '../../domain/entities/node_radio_stats.dart';
import '../../domain/entities/wardriving_session.dart';
import '../../domain/repositories/background_service.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/location_service.dart';
import '../../domain/repositories/master_connection.dart';
import '../../domain/repositories/recording_storage.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/upload_recording.dart';
import '../../domain/wigle_csv.dart';

/// A recorded map cell: its position and how many records fell in it.
typedef MapMarkerData = ({double latitude, double longitude, int count});

/// Owns the master connection, live GPS position and the active recording.
class ScannerController extends ChangeNotifier {
  ScannerController({
    required MasterConnection connection,
    required LocationService location,
    required RecordingStorage storage,
    required BackgroundService background,
    required UploadRecording uploadRecording,
    required HistoryRepository history,
    required SettingsRepository settings,
  }) : _connection = connection,
       _location = location,
       _storage = storage,
       _background = background,
       _uploadRecording = uploadRecording,
       _history = history,
       _settings = settings;

  final MasterConnection _connection;
  final LocationService _location;
  final RecordingStorage _storage;
  final BackgroundService _background;
  final UploadRecording _uploadRecording;
  final HistoryRepository _history;
  final SettingsRepository _settings;

  final _messages = StreamController<String>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  StreamSubscription<List<DiscoveredMaster>>? _discoverySub;
  bool _disposed = false;

  GeoPosition? _position;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _masterId;
  String? _masterName;
  List<DiscoveredMaster> _discovered = [];
  bool _isDiscovering = false;

  bool _isRecording = false;
  RecordingWriter? _writer;
  DateTime? _startedAt;
  GeoPosition? _lastRecordingPosition;
  double _distanceMeters = 0;
  final Set<String> _recordedKeys = {};
  final Set<String> _recordedWifi = {};
  final Set<String> _recordedBluetooth = {};
  // Record counts per ~11 m grid cell, keyed by rounded lat/lon.
  final Map<String, MapMarkerData> _markers = {};
  final Map<String, NodeRadioStats> _nodeStats = {};
  final Map<String, int> _rawTypeCounts = {};

  /// One-line notices for the UI to show (snackbars).
  Stream<String> get messages => _messages.stream;

  /// Latest GPS fix, or null before the first one.
  GeoPosition? get position => _position;

  /// Whether a master is connected.
  bool get isConnected => _isConnected;

  /// Whether a connection attempt is in progress.
  bool get isConnecting => _isConnecting;

  /// Id of the connected master, or null.
  String? get masterId => _masterId;

  /// Advertised master name, or a default when it has none.
  String get masterName =>
      (_masterName?.isNotEmpty ?? false) ? _masterName! : 'BNB-WarDriver';

  /// Masters found by the current scan.
  List<DiscoveredMaster> get discovered => _discovered;

  /// Whether a scan for masters is running.
  bool get isDiscovering => _isDiscovering;

  /// Whether a recording is in progress.
  bool get isRecording => _isRecording;

  /// Unique Wi-Fi access points in the current recording.
  int get wifiCount => _recordedWifi.length;

  /// Unique Bluetooth devices in the current recording.
  int get bluetoothCount => _recordedBluetooth.length;

  /// Recorded map cells for the current recording.
  Iterable<MapMarkerData> get markers => _markers.values;

  /// Per-node unique radio counts since the last (re)connect or recording start.
  Map<String, NodeRadioStats> get nodeStats => _nodeStats;

  /// Records received per type before any filtering, for diagnostics.
  Map<String, int> get rawTypeCounts => _rawTypeCounts;

  /// Starts listening to the master and GPS, then tries to reconnect to the last master.
  Future<void> init() async {
    await _background.init();
    _subscriptions
      ..add(_connection.records.listen(_onRecord))
      ..add(_connection.disconnected.listen((_) => _onLinkDropped()))
      ..add(_location.positions().listen(_onPosition));
    unawaited(autoConnectToLastDevice());
  }

  /// Notifies listeners unless the controller is disposed.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Publishes a message for the UI unless disposed.
  void _say(String message) {
    if (!_disposed) _messages.add(message);
  }

  /// Resets connection state after the link drops.
  void _onLinkDropped() {
    _isConnected = false;
    _masterId = null;
    _nodeStats.clear();
    _notify();
  }

  /// Stores a new fix and adds the distance travelled while recording.
  void _onPosition(GeoPosition position) {
    if (_isRecording) {
      final last = _lastRecordingPosition;
      if (last != null) {
        _distanceMeters += _location.distanceBetween(last, position);
      }
      _lastRecordingPosition = position;
    }
    _position = position;
    _notify();
  }

  // --- Discovery and connection -------------------------------------------

  /// Scans for masters, or reports that Bluetooth is off.
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    if (!await _connection.isBluetoothOn()) {
      _say('Please enable Bluetooth to scan for devices.');
      return;
    }

    _discovered = [];
    _isDiscovering = true;
    _notify();

    await _discoverySub?.cancel();
    _discoverySub = _connection.discoveries.listen((found) {
      _discovered = found;
      _notify();
    });

    await _connection.startDiscovery();
    unawaited(
      _connection.scanning.where((s) => !s).first.then((_) {
        _isDiscovering = false;
        _notify();
      }),
    );
  }

  /// Stops the scan for masters.
  Future<void> stopDiscovery() async {
    await _connection.stopDiscovery();
    _isDiscovering = false;
    _notify();
  }

  /// Silently reconnects to the master used last time, if it is in range.
  Future<void> autoConnectToLastDevice() async {
    final lastId = await _settings.getLastDeviceId();
    if (lastId == null || _isConnected) return;
    if (!await _connection.waitForBluetoothOn(const Duration(seconds: 5))) {
      return;
    }
    if (_disposed || _isConnected || _isConnecting) return;
    await connectTo(lastId, silent: true);
  }

  /// Connects to the master with [id] and remembers it; [silent] suppresses messages.
  Future<void> connectTo(String id, {bool silent = false}) async {
    _isConnecting = true;
    _notify();
    try {
      await _connection.connect(id);
      _isConnected = true;
      _masterId = _connection.connectedId;
      _masterName = _connection.connectedName;
      _isConnecting = false;
      _notify();
      await _settings.setLastDeviceId(id);
      if (!silent) {
        final name = _masterName;
        _say('Connected to ${name != null && name.isNotEmpty ? name : id}');
      }
    } catch (e) {
      _isConnecting = false;
      _notify();
      if (!silent) _say('Connection failed: $e');
    }
  }

  /// Stops scanning on the master, then closes the connection.
  Future<void> disconnect() async {
    if (!_isConnected) return;
    try {
      await _connection.sendCommand(MasterCommand.stopScan);
    } catch (_) {
      // The device may already be disconnected.
    }
    await _connection.disconnect();
    _onLinkDropped();
  }

  // --- Incoming records ---------------------------------------------------

  /// Updates node stats for every record and writes it to the recording when GPS is available.
  void _onRecord(ApRecord record) {
    _rawTypeCounts[record.type.label] =
        (_rawTypeCounts[record.type.label] ?? 0) + 1;
    final stats = _nodeStats.putIfAbsent(record.nodeId, NodeRadioStats.new);
    switch (record.type) {
      case RecordType.wifi:
        stats.uniqueWifiBssids.add(record.mac);
      case RecordType.bluetooth:
        stats.uniqueBluetoothIds.add(record.mac);
      case RecordType.unknown:
        break;
    }

    final position = _position;
    if (position != null) _writeIfRecording(record, position);
    _notify();
  }

  /// Appends the record to the recording file, skipping duplicates.
  void _writeIfRecording(ApRecord record, GeoPosition position) {
    final writer = _writer;
    if (!_isRecording || writer == null) return;
    if (!_recordedKeys.add('${record.type.label}:${record.mac}')) return;

    switch (record.type) {
      case RecordType.wifi:
        _recordedWifi.add(record.mac);
      case RecordType.bluetooth:
        _recordedBluetooth.add(record.mac);
      case RecordType.unknown:
        break;
    }
    writer.writeln(WigleCsv.row(record, position, DateTime.now()));

    final key =
        '${position.latitude.toStringAsFixed(4)},${position.longitude.toStringAsFixed(4)}';
    final existing = _markers[key];
    _markers[key] = (
      latitude: existing?.latitude ?? position.latitude,
      longitude: existing?.longitude ?? position.longitude,
      count: (existing?.count ?? 0) + 1,
    );
  }

  // --- Recording ----------------------------------------------------------

  /// Tells the master to scan, opens a CSV and starts background mode.
  Future<void> startRecording() async {
    if (_isRecording) return;
    try {
      await _connection.sendCommand(MasterCommand.startScan);
      final writer = await _storage.create(DateTime.now());
      WigleCsv.headerLines.forEach(writer.writeln);

      _writer = writer;
      _recordedKeys.clear();
      _recordedWifi.clear();
      _recordedBluetooth.clear();
      _markers.clear();
      _nodeStats.clear();
      _startedAt = DateTime.now();
      _lastRecordingPosition = _position;
      _distanceMeters = 0;
      _isRecording = true;
      _notify();
      await _background.start(_notificationText);
    } catch (e) {
      _say('Error starting recording: $e');
    }
  }

  /// Finalises the CSV, uploads it and saves the session; works even if Bluetooth dropped.
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    try {
      try {
        await _connection.sendCommand(MasterCommand.stopScan);
      } catch (_) {
        // Bluetooth may have dropped; still finalize and upload the file.
      }
      final writer = _writer;
      _isRecording = false;
      _writer = null;
      _notify();

      await writer?.close();
      await _background.stop();
      if (writer == null) return;

      final result = await _uploadRecording(writer.file);
      await _history.add(
        WardrivingSession(
          uniqueAccessPoints: _recordedKeys.length,
          uniqueBluetoothIds: _recordedBluetooth.length,
          durationSeconds: DateTime.now()
              .difference(_startedAt ?? DateTime.now())
              .inSeconds,
          distanceMeters: _distanceMeters,
          fileName: writer.file.uri.pathSegments.last,
          uploaded: result.uploadedToWdgwars && result.uploadedToWardrift,
          uploadedToWdgwars: result.uploadedToWdgwars,
          uploadedToWardrift: result.uploadedToWardrift,
          filePath: writer.file.path,
        ),
      );

      final failures = <String>[
        if (result.wdgwarsError != null) 'WDGWars: ${result.wdgwarsError}',
        if (result.wardriftError != null) 'Wardrift: ${result.wardriftError}',
      ];
      if (failures.isNotEmpty) {
        _say('CSV upload failed: ${failures.join('; ')}');
      }
    } catch (e) {
      _say('Error stopping scan: $e');
    }
  }

  /// Live duration, counts and distance for the foreground notification.
  String _notificationText() {
    final duration = DateTime.now().difference(_startedAt ?? DateTime.now());
    final distanceKm = (_distanceMeters / 1000).toStringAsFixed(2);
    return 'Duration: ${formatClock(duration)}  •  '
        'WiFi: ${_recordedWifi.length}  BT: ${_recordedBluetooth.length}  •  '
        '${distanceKm}km';
  }

  /// Cancels subscriptions and closes any open recording file.
  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _discoverySub?.cancel();
    _writer?.close();
    _messages.close();
    super.dispose();
  }
}
