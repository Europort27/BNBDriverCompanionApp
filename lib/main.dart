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
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
const int apRecordLength = 49;

void main() => runApp(const WigleScannerApp());

class WigleScannerApp extends StatelessWidget {
  const WigleScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const ScannerHomePage(),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
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

  @override
  void initState() {
    super.initState();
    _initWigleHeader();
    _determinePosition();
  }

  @override
  void dispose() {
    _scanResultsSub?.cancel();
    _connectionStateSub?.cancel();
    _characteristicValueSub?.cancel();
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
      setState(() {
        _currentPosition = position;
      });
    });
  }

  // Parses the packed wd_ap_record_t sent by master_node.
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

    if (_currentPosition == null) {
      _logCsvLine(
        "[dropped: no GPS fix yet] $mac,$ssid,$authMode,$channel,$rssi",
      );
      return;
    }

    String timeStr = DateTime.now().toString().substring(0, 19);

    String csvLine =
        "$mac,$ssid,$authMode,$timeStr,$channel,$rssi,"
        "${_currentPosition!.latitude},${_currentPosition!.longitude},"
        "${_currentPosition!.altitude},${_currentPosition!.accuracy},WIFI";

    setState(() {
      _csvRows.add(csvLine);
    });
    _logCsvLine(csvLine);
    _writeRecordIfRecording(mac, csvLine);
  }

  // Appends the record to the active recording file, skipping duplicate BSSIDs.
  void _writeRecordIfRecording(String mac, String csvLine) {
    if (!_isRecording || _recordingSink == null) return;
    if (_recordedBssids.contains(mac)) return;
    _recordedBssids.add(mac);
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

  void _simulateApRecord() {
    final record = List<int>.filled(apRecordLength, 0);
    record.setAll(0, [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    record.setAll(6, utf8.encode("Test_ESP32_Net"));
    record[39] = 191;
    record[40] = 6;
    record[42] = 3;
    _processIncomingApRecord(record);
  }

  Future<void> _saveCsvFile() async {
    if (_csvRows.length <= 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No records to save.")));
      return;
    }

    try {
      final directory = await _resolveWigleDirectory();
      final file = File(
        '${directory.path}/wigle_log_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(_csvRows.join('\n'));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Saved to: ${file.path}")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error saving file: $e")));
      }
    }
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
        _isRecording = true;
      });

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

      if (mounted && file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Recording stopped: ${file.path}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error stopping scan: $e")));
      }
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
                      ? "Recording (${_recordedBssids.length} unique APs)"
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
              child: ListView.builder(
                itemCount: _csvRows.length - 2,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  title: Text(
                    _csvRows[index + 2].split(',')[1],
                  ), // Displays SSID
                  subtitle: Text(
                    _csvRows[index + 2].split(',')[0],
                  ), // Displays BSSID/MAC
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "CSV Log",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  controller: _rawLogScrollController,
                  itemCount: _csvLog.length,
                  itemBuilder: (context, index) => Text(
                    _csvLog[index],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _simulateApRecord,
                  icon: const Icon(Icons.add),
                  label: const Text("Simulate Hit"),
                ),
                ElevatedButton.icon(
                  onPressed: _saveCsvFile,
                  icon: const Icon(Icons.save_alt),
                  label: const Text("Export CSV"),
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
