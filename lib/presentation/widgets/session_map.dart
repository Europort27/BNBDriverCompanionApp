import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/geo_position.dart';
import '../controllers/scanner_controller.dart';

/// Dark OpenStreetMap view that follows the phone and marks recorded cells.
class SessionMap extends StatefulWidget {
  const SessionMap({
    super.key,
    required this.position,
    required this.markers,
    required this.showMarkers,
  });

  final GeoPosition position;
  final Iterable<MapMarkerData> markers;
  final bool showMarkers;

  /// Creates the map state.
  @override
  State<SessionMap> createState() => _SessionMapState();
}

/// Keeps the map centred on the latest fix.
class _SessionMapState extends State<SessionMap> {
  final MapController _controller = MapController();
  bool _ready = false;

  /// Re-centres the map when the position changes.
  @override
  void didUpdateWidget(SessionMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final p = widget.position;
    if (_ready &&
        (p.latitude != oldWidget.position.latitude ||
            p.longitude != oldWidget.position.longitude)) {
      _controller.move(
        LatLng(p.latitude, p.longitude),
        _controller.camera.zoom,
      );
    }
  }

  /// Disposes the map controller.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Glowing circular marker in [color].
  Widget _dot({
    required Color color,
    required double blur,
    double spread = 0,
    Widget? child,
  }) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: color, blurRadius: blur, spreadRadius: spread),
        ],
      ),
      child: child,
    );
  }

  /// Builds the tile layer, own-position marker and recorded cells.
  @override
  Widget build(BuildContext context) {
    final p = widget.position;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: LatLng(p.latitude, p.longitude),
        initialZoom: 17,
        onMapReady: () => _ready = true,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          tileBuilder: darkModeTileBuilder,
          userAgentPackageName: 'com.example.bnbdriverapp',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(p.latitude, p.longitude),
              width: 20,
              height: 20,
              child: _dot(color: const Color(0xFF00FFF0), blur: 12, spread: 2),
            ),
            if (widget.showMarkers)
              for (final marker in widget.markers)
                Marker(
                  point: LatLng(marker.latitude, marker.longitude),
                  width: 32,
                  height: 32,
                  child: _dot(
                    color: const Color(0xFFFF00C8),
                    blur: 10,
                    child: Text(
                      '${marker.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
