import 'package:csv/csv.dart';

import 'entities/ap_record.dart';
import 'entities/geo_position.dart';

/// WiGLE CSV 1.4 formatting for recorded access points.
class WigleCsv {
  static const headerLines = [
    'WigleWifi-1.4,appRelease=1.0,model=ESP32-C5 Scanner,device=FlutterBLE,display=None,board=ESP32-C5',
    'MAC,SSID,AuthMode,FirstSeen,Channel,RSSI,CurrentLatitude,CurrentLongitude,AltitudeMeters,AccuracyMeters,Type',
  ];

  /// Formats one record seen at [position] as a CSV row (no line terminator).
  static String row(ApRecord record, GeoPosition position, DateTime seenAt) {
    return csv.encode([
      [
        record.mac,
        record.ssid,
        record.authModeName,
        seenAt.toString().substring(0, 19),
        record.channel.toString(),
        record.rssi,
        position.latitude,
        position.longitude,
        position.altitude,
        position.accuracy,
        record.type.label,
      ],
    ]);
  }

  /// Timestamped recording file name for [time].
  static String fileName(DateTime time) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return 'wigle_${time.year}${pad(time.month)}${pad(time.day)}_'
        '${pad(time.hour)}${pad(time.minute)}${pad(time.second)}.csv';
  }
}
