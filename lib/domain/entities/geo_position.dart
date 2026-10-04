/// A GPS fix.
class GeoPosition {
  const GeoPosition({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
}
