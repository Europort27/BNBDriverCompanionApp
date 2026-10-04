import 'package:flutter/material.dart';

import 'controllers/history_controller.dart';
import 'controllers/scanner_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/upload_progress_controller.dart';
import 'pages/devices_page.dart';
import 'pages/history_page.dart';
import 'pages/scanner_page.dart';
import 'pages/settings_page.dart';
import 'widgets/upload_progress_strip.dart';

/// Hosts the main screens behind a Material 3 navigation bar.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.scanner,
    required this.history,
    required this.settings,
    required this.uploadProgress,
  });

  final ScannerController scanner;
  final HistoryController history;
  final SettingsController settings;
  final UploadProgressController uploadProgress;

  /// Creates the shell state.
  @override
  State<AppShell> createState() => _AppShellState();
}

/// Tracks the selected tab and reloads History/Settings on each visit.
class _AppShellState extends State<AppShell> {
  int _index = 0;
  // Bumped on each visit so History/Settings reload saved data.
  int _historyRevision = 0;
  int _settingsRevision = 0;

  /// Builds the tab stack and the bottom bar with the upload progress strip.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          ScannerPage(controller: widget.scanner, settings: widget.settings),
          DevicesPage(controller: widget.scanner, settings: widget.settings),
          KeyedSubtree(
            key: ValueKey('history$_historyRevision'),
            child: HistoryPage(
              controller: widget.history,
              settings: widget.settings,
            ),
          ),
          KeyedSubtree(
            key: ValueKey('settings$_settingsRevision'),
            child: SettingsPage(controller: widget.settings),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UploadProgressStrip(controller: widget.uploadProgress),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() {
              if (index == 2) _historyRevision++;
              if (index == 3) _settingsRevision++;
              _index = index;
            }),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.radar_outlined),
                selectedIcon: Icon(Icons.radar),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(Icons.developer_board_outlined),
                selectedIcon: Icon(Icons.developer_board),
                label: 'Devices',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
