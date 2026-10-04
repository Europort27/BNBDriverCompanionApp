import '../entities/geo_position.dart';

/// Source of GPS fixes and distance calculations.
abstract class LocationService {
  /// Live fixes; completes immediately without events if location is unavailable.
  Stream<GeoPosition> positions();

  /// Distance in meters between two fixes.
  double distanceBetween(GeoPosition from, GeoPosition to);
}
