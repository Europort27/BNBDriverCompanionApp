import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';

/// Small "DEBUG" chip for app bars; hidden unless debug mode is on.
class DebugBadge extends StatelessWidget {
  const DebugBadge({super.key, required this.settings});

  final SettingsController settings;

  /// Builds the chip, or nothing when debug mode is off.
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        if (!settings.debugMode) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF0D101B),
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'DEBUG',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
