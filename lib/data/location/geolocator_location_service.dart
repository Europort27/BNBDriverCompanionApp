import 'package:geolocator/geolocator.dart';

import '../../domain/entities/geo_position.dart';
import '../../domain/repositories/location_service.dart';

/// Geolocator-backed [LocationService].
class GeolocatorLocationService implements LocationService {
  /// Streams high-accuracy fixes once permission is granted; empty if unavailable.
  @override
  Stream<GeoPosition> positions() async* {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).map(
      (p) => GeoPosition(
        latitude: p.latitude,
        longitude: p.longitude,
        altitude: p.altitude,
        accuracy: p.accuracy,
      ),
    );
  }

  /// Geodesic distance in meters between two fixes.
  @override
  double distanceBetween(GeoPosition from, GeoPosition to) =>
      Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
}
