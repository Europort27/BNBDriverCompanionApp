import '../entities/ap_record.dart';
import '../entities/discovered_master.dart';

/// Control commands the master understands.
enum MasterCommand {
  startScan(0x01),
  stopScan(0x02);

  const MasterCommand(this.code);

  final int code;
}

/// Link to the BNB-WarDriver master node.
abstract class MasterConnection {
  /// Decoded records pushed by the master.
  Stream<ApRecord> get records;

  /// Emits whenever the link drops, including after an explicit disconnect.
  Stream<void> get disconnected;

  /// Masters found by the current discovery scan.
  Stream<List<DiscoveredMaster>> get discoveries;

  /// True while a discovery scan is running.
  Stream<bool> get scanning;

  /// Whether a master is connected and streaming.
  bool get isConnected;

  /// Id of the connected master, or null.
  String? get connectedId;

  /// Advertised name of the connected master, or null.
  String? get connectedName;

  /// Whether the Bluetooth adapter is currently on.
  Future<bool> isBluetoothOn();

  /// Waits up to [timeout] for Bluetooth to turn on; false if it doesn't.
  Future<bool> waitForBluetoothOn(Duration timeout);

  /// Starts scanning for masters.
  Future<void> startDiscovery();

  /// Stops scanning.
  Future<void> stopDiscovery();

  /// Connects to the master with [id]; throws on failure.
  Future<void> connect(String id);

  /// Closes the connection.
  Future<void> disconnect();

  /// Sends [command] to the master; throws if not connected.
  Future<void> sendCommand(MasterCommand command);
}
