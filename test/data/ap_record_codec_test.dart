import 'package:bnbdriverapp/data/ble/ap_record_codec.dart';
import 'package:bnbdriverapp/domain/entities/ap_record.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> buildRecord({
  List<int> mac = const [0xAA, 0xBB, 0xCC, 0x00, 0x11, 0x22],
  String ssid = 'cafe',
  int rssi = -60,
  int channel = 6,
  int authMode = 3,
  List<int> nodeId = const [0, 0, 0, 0, 0, 0],
  int type = 0,
}) {
  final bytes = List<int>.filled(ApRecordCodec.recordLength, 0);
  bytes.setRange(0, 6, mac);
  final ssidBytes = ssid.codeUnits;
  bytes.setRange(6, 6 + ssidBytes.length, ssidBytes);
  bytes[39] = rssi & 0xff;
  bytes[40] = channel;
  bytes[42] = authMode;
  bytes.setRange(43, 49, nodeId);
  bytes[49] = type;
  return bytes;
}

void main() {
  test('decodes a Wi-Fi record', () {
    final record = ApRecordCodec.decode(buildRecord());

    expect(record.mac, 'aa:bb:cc:00:11:22');
    expect(record.ssid, 'cafe');
    expect(record.rssi, -60);
    expect(record.channel, 6);
    expect(record.authModeName, 'WPA2-PSK');
    expect(record.nodeId, 'Local (UART)');
    expect(record.type, RecordType.wifi);
  });

  test('decodes a Bluetooth record from a wireless node', () {
    final record = ApRecordCodec.decode(
      buildRecord(type: 1, nodeId: [1, 2, 3, 4, 5, 6], ssid: ''),
    );

    expect(record.type, RecordType.bluetooth);
    expect(record.nodeId, '01:02:03:04:05:06');
    expect(record.ssid, isEmpty);
  });

  test('flags unrecognised record types', () {
    expect(ApRecordCodec.decode(buildRecord(type: 9)).type, RecordType.unknown);
  });

  test('reports unknown auth modes', () {
    expect(
      ApRecordCodec.decode(buildRecord(authMode: 200)).authModeName,
      'UNKNOWN',
    );
  });
}
