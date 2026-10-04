/// A master seen during a BLE scan.
class DiscoveredMaster {
  const DiscoveredMaster({
    required this.id,
    required this.name,
    required this.rssi,
  });

  final String id;
  final String name;
  final int rssi;
}
