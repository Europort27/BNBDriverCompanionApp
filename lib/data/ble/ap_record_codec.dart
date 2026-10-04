import 'dart:convert';

import '../../domain/entities/ap_record.dart';

/// Decodes the packed 50-byte record sent by the master_node firmware.
class ApRecordCodec {
  static const int recordLength = 50;
  static const int _typeOffset = 49;

  /// Parses one [recordLength]-byte buffer into an [ApRecord].
  static ApRecord decode(List<int> bytes) {
    String hex(Iterable<int> values) =>
        values.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');

    final ssidBytes = bytes.sublist(6, 39);
    final ssidEnd = ssidBytes.indexOf(0);
    final nodeIdBytes = bytes.sublist(43, 49);

    return ApRecord(
      mac: hex(bytes.sublist(0, 6)),
      ssid: utf8.decode(
        ssidBytes.sublist(0, ssidEnd < 0 ? ssidBytes.length : ssidEnd),
        allowMalformed: true,
      ),
      rssi: bytes[39] > 127 ? bytes[39] - 256 : bytes[39],
      channel: bytes[40],
      authMode: bytes[42],
      nodeId: nodeIdBytes.every((b) => b == 0)
          ? 'Local (UART)'
          : hex(nodeIdBytes),
      type: switch (bytes[_typeOffset]) {
        0 => RecordType.wifi,
        1 => RecordType.bluetooth,
        _ => RecordType.unknown,
      },
    );
  }
}
