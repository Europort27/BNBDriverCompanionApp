import 'package:flutter/material.dart';

import '../controllers/scanner_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/debug_badge.dart';

/// Shows the connected master and the scanner nodes reporting through it.
class DevicesPage extends StatelessWidget {
  const DevicesPage({
    super.key,
    required this.controller,
    required this.settings,
  });

  final ScannerController controller;
  final SettingsController settings;

  /// Builds the master card, raw record counters and node list.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          DebugBadge(settings: settings),
          const SizedBox(width: 12),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final nodes = controller.nodeStats.entries.toList();
          final raw = controller.rawTypeCounts;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Master', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    controller.isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: controller.isConnected
                        ? colors.tertiary
                        : colors.outline,
                  ),
                  title: Text(
                    controller.isConnected
                        ? controller.masterName
                        : 'Not connected',
                  ),
                  subtitle: Text(
                    controller.masterId ??
                        'Use the Bluetooth button on the Scan tab to connect',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Raw records  WIFI ${raw['WIFI'] ?? 0}'
                '  |  BT ${raw['BT'] ?? 0}'
                '  |  UNKNOWN ${raw['UNKNOWN'] ?? 0}',
                style: TextStyle(fontSize: 11, color: colors.outline),
              ),
              const SizedBox(height: 24),
              Text(
                'Connected Nodes: ${nodes.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (nodes.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.developer_board_off),
                    title: Text('No nodes reporting yet'),
                  ),
                )
              else
                for (final node in nodes) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.developer_board),
                      title: Text(node.key),
                      subtitle: Text(
                        '${node.value.uniqueWifiBssids.length} WiFi  |  '
                        '${node.value.uniqueBluetoothIds.length} BT',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}
