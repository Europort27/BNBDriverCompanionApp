/// Radio that produced a record.
enum RecordType {
  wifi('WIFI'),
  bluetooth('BT'),
  unknown('UNKNOWN');

  const RecordType(this.label);

  final String label;
}

/// One Wi-Fi access point or Bluetooth device reported by a scanner node.
class ApRecord {
  const ApRecord({
    required this.mac,
    required this.ssid,
    required this.rssi,
    required this.channel,
    required this.authMode,
    required this.nodeId,
    required this.type,
  });

  static const _authModeNames = [
    'OPEN',
    'WEP',
    'WPA-PSK',
    'WPA2-PSK',
    'WPA/WPA2-PSK',
    'WPA2-ENTERPRISE',
    'WPA3-PSK',
    'WPA2/WPA3-PSK',
    'WAPI-PSK',
  ];

  final String mac;
  final String ssid;
  final int rssi;
  final int channel;
  final int authMode;
  final String nodeId;
  final RecordType type;

  /// Human-readable Wi-Fi auth mode, or UNKNOWN when out of range.
  String get authModeName =>
      authMode < _authModeNames.length ? _authModeNames[authMode] : 'UNKNOWN';
}
