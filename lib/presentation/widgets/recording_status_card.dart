import 'package:flutter/material.dart';

import '../controllers/scanner_controller.dart';

/// Terminal-style panel with recording state, master link and live counts.
class RecordingStatusCard extends StatelessWidget {
  const RecordingStatusCard({super.key, required this.controller});

  final ScannerController controller;

  /// Builds the panel; it glows while recording.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recording = controller.isRecording;
    final connected = controller.isConnected;
    final accent = recording ? colors.secondary : colors.outline;
    final linkColor = connected ? colors.tertiary : colors.secondary;
    const mono = TextStyle(fontSize: 12, letterSpacing: 1);

    Widget countRow(String label, int count, Color color) {
      return Row(
        children: [
          Text(
            '> $label',
            style: mono.copyWith(color: const Color(0xFF8EA6B8)),
          ),
          const Spacer(),
          Text(
            count.toString().padLeft(4, '0'),
            style: mono.copyWith(
              color: recording ? color : colors.outline,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D101B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent, width: 1.2),
        boxShadow: recording
            ? [
                BoxShadow(
                  color: colors.secondary.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: recording
                      ? [BoxShadow(color: accent, blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                recording ? 'REC // LIVE' : 'STANDBY',
                style: mono.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Icon(
                connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                size: 14,
                color: linkColor,
              ),
              const SizedBox(width: 4),
              Text(
                connected ? 'CONNECTED' : 'DISCONNECTED',
                style: mono.copyWith(fontSize: 11, color: linkColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          countRow('WIFI APs', controller.wifiCount, colors.primary),
          const SizedBox(height: 4),
          countRow('BT APs', controller.bluetoothCount, colors.tertiary),
        ],
      ),
    );
  }
}
