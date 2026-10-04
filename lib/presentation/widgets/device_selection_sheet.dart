import 'package:flutter/material.dart';

import '../controllers/scanner_controller.dart';

/// Bottom sheet listing nearby masters; tapping one connects. Scanning stops when it closes.
Future<void> showDeviceSelectionSheet(
  BuildContext context,
  ScannerController controller,
) {
  controller.startDiscovery();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final devices = controller.discovered;
        return SafeArea(
          child: SizedBox(
            height: 400,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select BNB-WarDriver',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (controller.isDiscovering)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: devices.isEmpty
                      ? const Center(
                          child: Text('No BNB-WarDriver devices found yet...'),
                        )
                      : ListView.builder(
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            return ListTile(
                              leading: const Icon(Icons.bluetooth),
                              title: Text(
                                device.name.isNotEmpty
                                    ? device.name
                                    : 'Unknown device',
                              ),
                              subtitle: Text(device.id),
                              trailing: Text('${device.rssi} dBm'),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                controller.stopDiscovery();
                                controller.connectTo(device.id);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ).whenComplete(controller.stopDiscovery);
}
