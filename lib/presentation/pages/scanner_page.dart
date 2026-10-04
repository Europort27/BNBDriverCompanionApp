import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../controllers/scanner_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/debug_badge.dart';
import '../widgets/device_selection_sheet.dart';
import '../widgets/recording_status_card.dart';
import '../widgets/session_map.dart';

/// Main screen: recording status, live map and Start/Stop controls.
class ScannerPage extends StatefulWidget {
  const ScannerPage({
    super.key,
    required this.controller,
    required this.settings,
  });

  final ScannerController controller;
  final SettingsController settings;

  /// Creates the page state.
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

/// Shows controller messages as snackbars.
class _ScannerPageState extends State<ScannerPage> {
  StreamSubscription<String>? _messageSub;

  ScannerController get _controller => widget.controller;

  /// Starts showing controller messages as snackbars.
  @override
  void initState() {
    super.initState();
    _messageSub = _controller.messages.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  /// Stops listening for messages.
  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  /// Asks before disconnecting, and blocks it entirely while recording.
  Future<void> _confirmDisconnect() async {
    if (_controller.isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop recording before disconnecting')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text('Disconnect from the BNB-WarDriver master?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.disconnect();
  }

  /// Builds the app bar, status card, map and Start/Stop buttons.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final colors = Theme.of(context).colorScheme;
        final isConnected = _controller.isConnected;
        final position = _controller.position;
        return Scaffold(
          appBar: AppBar(
            title: const Text('BNB Wardriver v1.0'),
            actions: [
              DebugBadge(settings: widget.settings),
              IconButton(
                icon: _controller.isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                      ),
                tooltip: isConnected ? 'Disconnect' : 'Connect to ESP32-C5',
                onPressed: _controller.isConnecting
                    ? null
                    : (isConnected
                          ? _confirmDisconnect
                          : () =>
                                showDeviceSelectionSheet(context, _controller)),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                RecordingStatusCard(controller: _controller),
                const SizedBox(height: 10),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: Color(0xFFFF00C8),
                        width: 1.5,
                      ),
                    ),
                    child: position == null
                        ? const Center(child: Text('Acquiring GPS Lock...'))
                        : SessionMap(
                            position: position,
                            markers: _controller.markers,
                            showMarkers: _controller.isRecording,
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isConnected && !_controller.isRecording
                          ? _controller.startRecording
                          : null,
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text('Start'),
                      style: AppTheme.neonButton(colors.tertiary),
                    ),
                    ElevatedButton.icon(
                      onPressed: _controller.isRecording
                          ? _controller.stopRecording
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: AppTheme.neonButton(colors.secondary),
                    ),
                  ],
                ),
                SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        );
      },
    );
  }
}
