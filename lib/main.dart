// import 'package:flutter/material.dart';

// void main() {
//   runApp(const MainApp());
// }

// class MainApp extends StatelessWidget {
//   const MainApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       home: Scaffold(body: Center(child: Text('Hello World!'))),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// GATT UUIDs exposed by the master_node firmware. NimBLE stores the UUID
// bytes little-endian, so these are the canonical client-facing strings.
final Guid masterServiceUuid = Guid("88776655-4433-2211-ffee-ddccbbaa0001");
final Guid apStreamCharacteristicUuid = Guid(
  "88776655-4433-2211-ffee-ddccbbaa0002",
);
final Guid controlCharacteristicUuid = Guid(
  "88776655-4433-2211-ffee-ddccbbaa0003",
);

const int startScanCommand = 0x01;
const int stopScanCommand = 0x02;
const int apRecordLength = 50;
const int apRecordTypeOffset = 49;
const String wdgwarsApiKeyPreference = 'wdgwars_api_key';
const String wardrivingHistoryPreference = 'wardriving_history';
const MethodChannel _powerManagementChannel = MethodChannel(
  'bnbdriverapp/power_management',
);
const String wardrivingNotificationChannelId = 'wardriving_service';

// The notification content is pushed from the UI isolate via updateService,
// so this handler only needs to keep the foreground service alive.
@pragma('vm:entry-point')
void wardrivingServiceStartCallback() {
  FlutterForegroundTask.setTaskHandler(_WardrivingTaskHandler());
}

class _WardrivingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

// Tracks the unique Wifi/BT radios discovered per scanner node.
class NodeRadioStats {
  final Set<String> uniqueWifiBssids = {};
  final Set<String> uniqueBluetoothIds = {};

  int get totalUnique => uniqueWifiBssids.length + uniqueBluetoothIds.length;
}

class WardrivingSession {
  const WardrivingSession({
    required this.uniqueAccessPoints,
    required this.uniqueBluetoothIds,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.fileName,
    required this.uploaded,
  });

  final int uniqueAccessPoints;
  final int uniqueBluetoothIds;
  final int durationSeconds;
  final double distanceMeters;
  final String fileName;
  final bool uploaded;

  Map<String, dynamic> toJson() => {
        'uniqueAccessPoints': uniqueAccessPoints,
        'uniqueBluetoothIds': uniqueBluetoothIds,
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'fileName': fileName,
        'uploaded': uploaded,
      };

  factory WardrivingSession.fromJson(Map<String, dynamic> json) {
    return WardrivingSession(
      uniqueAccessPoints: json['uniqueAccessPoints'] as int,
      uniqueBluetoothIds: json['uniqueBluetoothIds'] as int? ?? 0,
      durationSeconds: json['durationSeconds'] as int,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      fileName: json['fileName'] as String,
      uploaded: json['uploaded'] as bool,
    );
  }
}

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runApp(const WigleScannerApp());
}

class WigleScannerApp extends StatelessWidget {
  const WigleScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const ScannerHomePage(),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'monospace',
        scaffoldBackgroundColor: const Color(0xFF090B12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          onPrimary: Color(0xFF001014),
          secondary: Color(0xFFFF2BD6),
          onSecondary: Color(0xFF1A0015),
          tertiary: Color(0xFFB7FF00),
          surface: Color(0xFF111522),
          onSurface: Color(0xFFE5F7FF),
          surfaceContainerHighest: Color(0xFF1A2030),
          outline: Color(0xFF3A5064),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D101B),
          foregroundColor: Color(0xFFE5F7FF),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFFE5F7FF),
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111522),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF26364A)),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFF00E5FF),
          textColor: Color(0xFFE5F7FF),
          subtitleTextStyle: TextStyle(color: Color(0xFF8EA6B8)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00B8CC),
            foregroundColor: const Color(0xFF001014),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B8CC),
            foregroundColor: const Color(0xFF001014),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D101B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF3A5064)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF111522),
          modalBackgroundColor: Color(0xFF111522),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1A2030),
          contentTextStyle: TextStyle(color: Color(0xFFE5F7FF)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF00E5FF),
        ),
      ),
    );
  }
}

class ScannerHomePage extends StatefulWidget {
  const ScannerHomePage({super.key});

  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  final List<String> _csvRows = [];
  final List<String> _csvLog = [];
  final ScrollController _rawLogScrollController = ScrollController();
  Position? _currentPosition;

  BluetoothDevice? _connectedDevice;
  bool _isBleScanning = false;
  bool _isConnecting = false;
  List<ScanResult> _scanResults = [];

  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  StreamSubscription<List<int>>? _characteristicValueSub;
  BluetoothCharacteristic? _controlCharacteristic;
  final List<int> _incomingBleData = [];

  bool _isRecording = false;
  File? _recordingFile;
  IOSink? _recordingSink;
  final Set<String> _recordedBssids = {};
  final Set<String> _recordedWifiBssids = {};
  final Set<String> _recordedBluetoothIds = {};
  final Map<String, NodeRadioStats> _nodeStats = {};
  DateTime? _recordingStartedAt;
  Position? _lastRecordingPosition;
  double _recordingDistanceMeters = 0;
  Timer? _notificationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initWigleHeader();
    _determinePosition();
    _initForegroundTask();
  }

  @override
  void dispose() {
    _scanResultsSub?.cancel();
    _connectionStateSub?.cancel();
    _characteristicValueSub?.cancel();
    _notificationUpdateTimer?.cancel();
    _rawLogScrollController.dispose();
    _recordingSink?.close();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  // Scans for nearby BNB-WarDriver master devices.
  Future<void> _startBleScan() async {
    if (_isBleScanning) return;

    if (Platform.isAndroid) {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please enable Bluetooth to scan for devices."),
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _scanResults = [];
      _isBleScanning = true;
    });

    await _scanResultsSub?.cancel();
    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results
            .where(
              (r) =>
                  r.advertisementData.advName.toUpperCase().contains(
                    "BNB-WARDRIVER",
                  ) ||
                  r.advertisementData.serviceUuids.contains(masterServiceUuid),
            )
            .toList();
      });
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    FlutterBluePlus.isScanning.where((s) => s == false).first.then((_) {
      if (mounted) setState(() => _isBleScanning = false);
    });
  }

  Future<void> _stopBleScan() async {
    await FlutterBluePlus.stopScan();
    if (mounted) setState(() => _isBleScanning = false);
  }

  void _showDeviceSelectionSheet() {
    _startBleScan();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            _scanResultsSub?.cancel();
            _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
              final filtered = results
                  .where(
                    (r) =>
                        r.advertisementData.advName.toUpperCase().contains(
                          "BNB-WARDRIVER",
                        ) ||
                        r.advertisementData.serviceUuids.contains(
                          masterServiceUuid,
                        ),
                  )
                  .toList();
              setState(() => _scanResults = filtered);
              sheetSetState(() => _scanResults = filtered);
            });

            return SafeArea(
              child: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Select BNB-WarDriver",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_isBleScanning)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _scanResults.isEmpty
                          ? const Center(
                              child: Text(
                                "No BNB-WarDriver devices found yet...",
                              ),
                            )
                          : ListView.builder(
                              itemCount: _scanResults.length,
                              itemBuilder: (context, index) {
                                final result = _scanResults[index];
                                return ListTile(
                                  leading: const Icon(Icons.bluetooth),
                                  title: Text(
                                    result.advertisementData.advName.isNotEmpty
                                        ? result.advertisementData.advName
                                        : "Unknown device",
                                  ),
                                  subtitle: Text(result.device.remoteId.str),
                                  trailing: Text("${result.rssi} dBm"),
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    _stopBleScan();
                                    _connectToDevice(result.device);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => _stopBleScan());
  }

  // Connects to the master and starts its WiFi scan stream.
  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isConnecting = true);

    try {
      await _connectionStateSub?.cancel();
      _connectionStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            _connectedDevice = null;
          });
        }
      });

      await device.connect(timeout: const Duration(seconds: 10));
      await _subscribeToWifiData(device);

      setState(() {
        _connectedDevice = device;
        _isConnecting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Connected to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.str}",
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Connection failed: $e")));
      }
    }
  }

  // Discovers the master service, subscribes to AP records, and starts scanning.
  Future<void> _subscribeToWifiData(BluetoothDevice device) async {
    final services = await device.discoverServices();

    final service = services.firstWhere(
      (candidate) => candidate.uuid == masterServiceUuid,
      orElse: () => throw Exception("Master GATT service not found"),
    );
    final target = service.characteristics.firstWhere(
      (characteristic) => characteristic.uuid == apStreamCharacteristicUuid,
      orElse: () =>
          throw Exception("Master AP stream characteristic not found"),
    );
    final control = service.characteristics.firstWhere(
      (characteristic) => characteristic.uuid == controlCharacteristicUuid,
      orElse: () => throw Exception("Master control characteristic not found"),
    );

    await target.setNotifyValue(true);
    await _characteristicValueSub?.cancel();
    _controlCharacteristic = control;
    _incomingBleData.clear();
    _characteristicValueSub = target.lastValueStream.listen((value) {
      _incomingBleData.addAll(value);
      while (_incomingBleData.length >= apRecordLength) {
        final record = _incomingBleData.sublist(0, apRecordLength);
        _incomingBleData.removeRange(0, apRecordLength);
        _processIncomingApRecord(record);
      }
    });
  }

  Future<void> _sendScanCommand(int command) async {
    final control = _controlCharacteristic;
    if (control == null || _connectedDevice == null) {
      throw Exception("Connect to the master node first");
    }

    await control.write(
      [command],
      withoutResponse:
          control.properties.writeWithoutResponse && !control.properties.write,
    );
  }

  void _logCsvLine(String csvLine) {
    setState(() => _csvLog.add(csvLine));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rawLogScrollController.hasClients) return;
      _rawLogScrollController.jumpTo(
        _rawLogScrollController.position.maxScrollExtent,
      );
    });
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice == null) return;
    if (_controlCharacteristic != null) {
      try {
        await _sendScanCommand(stopScanCommand);
      } catch (_) {
        // The device may already be disconnected.
      }
    }
    await _characteristicValueSub?.cancel();
    await _connectedDevice!.disconnect();
    _controlCharacteristic = null;
    _incomingBleData.clear();
    setState(() {
      _connectedDevice = null;
    });
  }

  void _initWigleHeader() {
    // WiGle standard metadata and columns lines
    _csvRows.add(
      "WigleWifi-1.4,appRelease=1.0,model=ESP32-C5 Scanner,device=FlutterBLE,display=None,board=ESP32-C5",
    );
    _csvRows.add(
      "MAC,SSID,AuthMode,FirstSeen,Channel,RSSI,CurrentLatitude,CurrentLongitude,AltitudeMeters,AccuracyMeters,Type",
    );
  }

  // Request high-accuracy GPS permissions and position
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      if (_isRecording && _lastRecordingPosition != null) {
        _recordingDistanceMeters += Geolocator.distanceBetween(
          _lastRecordingPosition!.latitude,
          _lastRecordingPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }
      if (_isRecording) _lastRecordingPosition = position;
      setState(() {
        _currentPosition = position;
      });
    });
  }

  // Parses the packed Wi-Fi/Bluetooth record sent by master_node.
  void _processIncomingApRecord(List<int> record) {
    final mac = record
        .sublist(0, 6)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(':');
    final ssidBytes = record.sublist(6, 39);
    final ssidLength = ssidBytes.indexOf(0);
    final ssid = utf8.decode(
      ssidBytes.sublist(0, ssidLength < 0 ? ssidBytes.length : ssidLength),
      allowMalformed: true,
    );
    final rssi = record[39] > 127 ? record[39] - 256 : record[39];
    final channel = record[40].toString();
    final authMode = _authModeName(record[42]);
    final nodeIdBytes = record.sublist(43, 49);
    final nodeId = nodeIdBytes.every((byte) => byte == 0)
        ? 'Local (UART)'
        : nodeIdBytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join(':');
    final recordType = switch (record[apRecordTypeOffset]) {
      0 => 'WIFI',
      1 => 'BT',
      _ => 'UNKNOWN',
    };

    setState(() {
      final nodeStats = _nodeStats.putIfAbsent(nodeId, () => NodeRadioStats());
      if (recordType == 'WIFI') {
        nodeStats.uniqueWifiBssids.add(mac);
      } else if (recordType == 'BT') {
        nodeStats.uniqueBluetoothIds.add(mac);
      }
    });

    if (_currentPosition == null) {
      _logCsvLine(
        "[dropped: no GPS fix yet] $mac,$ssid,$authMode,$channel,$rssi,$recordType",
      );
      return;
    }

    String timeStr = DateTime.now().toString().substring(0, 19);

    String csvLine =
        "$mac,$ssid,$authMode,$timeStr,$channel,$rssi,"
        "${_currentPosition!.latitude},${_currentPosition!.longitude},"
        "${_currentPosition!.altitude},${_currentPosition!.accuracy},$recordType";

    setState(() {
      _csvRows.add(csvLine);
    });
    _logCsvLine(csvLine);
    _writeRecordIfRecording(mac, csvLine);
  }

  // Appends the record to the active recording file, skipping duplicate BSSIDs.
  void _writeRecordIfRecording(String mac, String csvLine) {
    if (!_isRecording || _recordingSink == null) return;
    final recordType = csvLine.split(',').last;
    final recordKey = '$recordType:$mac';
    if (_recordedBssids.contains(recordKey)) return;
    _recordedBssids.add(recordKey);
    if (recordType == 'WIFI') {
      _recordedWifiBssids.add(mac);
    } else if (recordType == 'BT') {
      _recordedBluetoothIds.add(mac);
    }
    _recordingSink!.writeln(csvLine);
  }

  String _authModeName(int authMode) {
    const names = [
      "OPEN",
      "WEP",
      "WPA-PSK",
      "WPA2-PSK",
      "WPA/WPA2-PSK",
      "WPA2-ENTERPRISE",
      "WPA3-PSK",
      "WPA2/WPA3-PSK",
      "WAPI-PSK",
    ];
    return authMode < names.length ? names[authMode] : "UNKNOWN";
  }

  // Resolves a writable directory for Wigle CSV files, requesting storage
  // permissions and falling back to app-private external storage.
  Future<Directory> _resolveWigleDirectory() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    try {
      final documentsDir = Directory('/storage/emulated/0/Documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      return documentsDir;
    } catch (_) {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception("No writable storage directory available");
      }
      return directory;
    }
  }

  String _timestampForFilename(DateTime time) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return "${time.year}${pad(time.month)}${pad(time.day)}_"
        "${pad(time.hour)}${pad(time.minute)}${pad(time.second)}";
  }

  // Creates a new Wigle-formatted CSV file and starts appending live AP
  // records to it, skipping BSSIDs already written to this recording.
  Future<void> _startRecording() async {
    if (_isRecording) return;

    try {
      await _sendScanCommand(startScanCommand);
      final directory = await _resolveWigleDirectory();
      final fileName = 'wigle_${_timestampForFilename(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      final sink = file.openWrite(mode: FileMode.write);
      sink.writeln(_csvRows[0]);
      sink.writeln(_csvRows[1]);

      setState(() {
        _recordingFile = file;
        _recordingSink = sink;
        _recordedBssids.clear();
        _recordedWifiBssids.clear();
        _recordedBluetoothIds.clear();
        _nodeStats.clear();
        _recordingStartedAt = DateTime.now();
        _lastRecordingPosition = _currentPosition;
        _recordingDistanceMeters = 0;
        _isRecording = true;
      });
      await _setCpuWakeLock(true);
      await _startForegroundService();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Recording to: ${file.path}")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error starting recording: $e")));
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      await _sendScanCommand(stopScanCommand);
      final sink = _recordingSink;
      final file = _recordingFile;
      setState(() {
        _isRecording = false;
        _recordingSink = null;
        _recordingFile = null;
      });

      await sink?.flush();
      await sink?.close();
      await _setCpuWakeLock(false);
      await _stopForegroundService();

      var uploadSucceeded = false;
      if (file != null) {
        try {
          await _uploadCsvFile(file);
          uploadSucceeded = true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("CSV upload failed: $e")),
            );
          }
        }
        await _saveWardrivingSession(file, uploadSucceeded);
        if (mounted && uploadSucceeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("CSV uploaded to WDGWars.pl: ${file.path}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error stopping scan: $e")));
      }
    }
  }

  Future<void> _setCpuWakeLock(bool enabled) async {
    if (!Platform.isAndroid) return;
    await _powerManagementChannel.invokeMethod<void>(
      enabled ? 'acquireWakeLock' : 'releaseWakeLock',
    );
  }

  void _initForegroundTask() {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: wardrivingNotificationChannelId,
        channelName: 'Wardriving Service',
        channelDescription: 'Shows live wardriving stats while recording.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String pad(int value) => value.toString().padLeft(2, '0');
    final hours = pad(duration.inHours);
    final minutes = pad(duration.inMinutes.remainder(60));
    final seconds = pad(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  String _buildNotificationText() {
    final duration = DateTime.now().difference(
      _recordingStartedAt ?? DateTime.now(),
    );
    final distanceKm = (_recordingDistanceMeters / 1000).toStringAsFixed(2);
    return "Duration: ${_formatDuration(duration)}  •  "
        "WiFi: ${_recordedWifiBssids.length}  BT: ${_recordedBluetoothIds.length}  •  "
        "${distanceKm}km";
  }

  // Starts the persistent notification and keeps it refreshed with live stats.
  Future<void> _startForegroundService() async {
    if (!Platform.isAndroid) return;

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    await FlutterForegroundTask.startService(
      notificationTitle: "BNB Wardriving in progress",
      notificationText: _buildNotificationText(),
      callback: wardrivingServiceStartCallback,
    );

    _notificationUpdateTimer?.cancel();
    _notificationUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      FlutterForegroundTask.updateService(notificationText: _buildNotificationText());
    });
  }

  Future<void> _stopForegroundService() async {
    if (!Platform.isAndroid) return;
    _notificationUpdateTimer?.cancel();
    _notificationUpdateTimer = null;
    await FlutterForegroundTask.stopService();
  }

  Future<void> _saveWardrivingSession(File file, bool uploaded) async {
    final preferences = await SharedPreferences.getInstance();
    final storedSessions = preferences.getStringList(
          wardrivingHistoryPreference,
        ) ??
        [];
    final session = WardrivingSession(
      uniqueAccessPoints: _recordedBssids.length,
      uniqueBluetoothIds: _recordedBluetoothIds.length,
      durationSeconds: DateTime.now()
          .difference(_recordingStartedAt ?? DateTime.now())
          .inSeconds,
      distanceMeters: _recordingDistanceMeters,
      fileName: file.uri.pathSegments.last,
      uploaded: uploaded,
    );
    storedSessions.add(jsonEncode(session.toJson()));
    await preferences.setStringList(wardrivingHistoryPreference, storedSessions);
  }

  Future<void> _uploadCsvFile(File file) async {
    final preferences = await SharedPreferences.getInstance();
    final apiKey = preferences.getString(wdgwarsApiKeyPreference)?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Add your WDGWars API key in Settings first");
    }

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("https://wdgwars.pl/api/upload-csv"),
    )
      ..headers["X-API-Key"] = apiKey
      ..files.add(await http.MultipartFile.fromPath("file", file.path));

    final response = await request.send().timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("WDGWars returned HTTP ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectedDevice != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text("ESP32-C5 WiGle Logger"),
        actions: [
          IconButton(
            icon: _isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                  ),
            tooltip: isConnected ? "Disconnect" : "Connect to ESP32-C5",
            onPressed: _isConnecting
                ? null
                : (isConnected ? _disconnectDevice : _showDeviceSelectionSheet),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "History",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HistoryPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Settings",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        key: UniqueKey(),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.bluetooth,
                  color: isConnected ? Colors.blue : Colors.grey,
                ),
                title: Text(
                  isConnected
                      ? "Connected: ${_connectedDevice!.platformName.isNotEmpty ? _connectedDevice!.platformName : _connectedDevice!.remoteId.str}"
                      : "Not connected to ESP32-C5",
                ),
                subtitle: Text(
                  isConnected
                      ? "Receiving wifi AP data"
                      : "Tap the bluetooth icon to connect",
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.fiber_manual_record,
                  color: _isRecording ? Colors.red : Colors.grey,
                ),
                title: Text(
                  _isRecording
                      ? "Recording (${_recordedWifiBssids.length} unique WiFi APs, ${_recordedBluetoothIds.length} unique Bluetooth IDs)"
                      : "Not recording",
                ),
                subtitle: Text(
                  _recordingFile?.path ?? "Press Start to begin a new CSV log",
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.red),
                title: Text(
                  _currentPosition != null
                      ? "Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(5)}"
                      : "Acquiring GPS Lock...",
                ),
                subtitle: Text(
                  "Accuracy: ${_currentPosition?.accuracy.toStringAsFixed(1) ?? '0'}m",
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        "Last Scan Totals - Nodes (${_nodeStats.length})",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: _nodeStats.isEmpty
                          ? const Center(
                              child: Text("No node data received yet"),
                            )
                          : ListView.builder(
                              itemCount: _nodeStats.length,
                              itemBuilder: (context, index) {
                                final nodeId = _nodeStats.keys.elementAt(index);
                                final stats = _nodeStats[nodeId]!;
                                return ListTile(
                                  leading: const Icon(Icons.developer_board),
                                  title: Text(nodeId),
                                  subtitle: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.wifi, size: 16),
                                      const SizedBox(width: 4),
                                      Text("${stats.uniqueWifiBssids.length}"),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.bluetooth, size: 16),
                                      const SizedBox(width: 4),
                                      Text("${stats.uniqueBluetoothIds.length}"),
                                    ],
                                  ),
                                  trailing: Text("${stats.totalUnique}"),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: isConnected && !_isRecording
                      ? _startRecording
                      : null,
                  icon: const Icon(Icons.fiber_manual_record),
                  label: const Text("Start"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isConnected && _isRecording
                      ? _stopRecording
                      : null,
                  icon: const Icon(Icons.stop),
                  label: const Text("Stop"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _obscureApiKey = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    _apiKeyController.text = preferences.getString(wdgwarsApiKeyPreference) ?? '';
    setState(() => _isLoading = false);
  }

  Future<void> _saveApiKey() async {
    setState(() => _isSaving = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      wdgwarsApiKeyPreference,
      _apiKeyController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("WDGWars API key saved.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  "WDGWars",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: "API key",
                    hintText: "Enter your WDGWars API key",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      tooltip: _obscureApiKey ? "Show API key" : "Hide API key",
                      onPressed: () {
                        setState(() => _obscureApiKey = !_obscureApiKey);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveApiKey,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text("Save API key"),
                ),
              ],
            ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<WardrivingSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final storedSessions = preferences.getStringList(
          wardrivingHistoryPreference,
        ) ??
        [];
    final sessions = <WardrivingSession>[];
    for (final storedSession in storedSessions.reversed) {
      try {
        sessions.add(
          WardrivingSession.fromJson(
            jsonDecode(storedSession) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Ignore malformed entries from an older app version.
      }
    }
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatDistance(double meters) {
    return '${(meters / 1609.344).toStringAsFixed(2)} mi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text("No wardriving sessions yet."))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          session.uploaded ? Icons.check_circle : Icons.cancel,
                          color: session.uploaded ? Colors.green : Colors.red,
                        ),
                        title: Text(session.fileName),
                        subtitle: Text(
                          "${session.uniqueAccessPoints} unique APs  |  "
                          "${session.uniqueBluetoothIds} unique BT IDs  |  "
                          "${_formatDuration(session.durationSeconds)}  |  "
                          "${_formatDistance(session.distanceMeters)}",
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
