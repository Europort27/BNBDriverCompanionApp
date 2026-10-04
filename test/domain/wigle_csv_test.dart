import 'package:bnbdriverapp/domain/entities/ap_record.dart';
import 'package:bnbdriverapp/domain/entities/geo_position.dart';
import 'package:bnbdriverapp/domain/wigle_csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const position = GeoPosition(
    latitude: 40.5,
    longitude: -74.25,
    altitude: 12,
    accuracy: 4.5,
  );

  test('formats a row ending in the record type without a line terminator', () {
    const record = ApRecord(
      mac: 'aa:bb:cc:00:11:22',
      ssid: 'cafe',
      rssi: -60,
      channel: 6,
      authMode: 3,
      nodeId: 'Local (UART)',
      type: RecordType.bluetooth,
    );

    final row = WigleCsv.row(
      record,
      position,
      DateTime(2026, 10, 4, 8, 30, 15),
    );

    expect(
      row,
      'aa:bb:cc:00:11:22,cafe,WPA2-PSK,2026-10-04 08:30:15,6,-60,40.5,-74.25,12.0,4.5,BT',
    );
  });

  test('quotes SSIDs containing commas', () {
    const record = ApRecord(
      mac: 'aa:bb:cc:00:11:22',
      ssid: 'a,b',
      rssi: -1,
      channel: 1,
      authMode: 0,
      nodeId: 'n',
      type: RecordType.wifi,
    );

    expect(WigleCsv.row(record, position, DateTime(2026)).split(',')[1], '"a');
  });

  test('has the WiGLE header lines', () {
    expect(WigleCsv.headerLines, hasLength(2));
    expect(WigleCsv.headerLines.first, startsWith('WigleWifi-1.4'));
    expect(WigleCsv.headerLines.last, startsWith('MAC,SSID,AuthMode'));
  });

  test('builds a sortable file name', () {
    expect(
      WigleCsv.fileName(DateTime(2026, 1, 2, 3, 4, 5)),
      'wigle_20260102_030405.csv',
    );
  });
}
