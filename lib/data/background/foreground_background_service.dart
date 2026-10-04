import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../domain/repositories/background_service.dart';

const _powerChannel = MethodChannel('bnbdriverapp/power_management');
const _notificationChannelId = 'wardriving_service';

/// Foreground-service entry point; it only keeps the service alive because the UI isolate pushes the notification text.
@pragma('vm:entry-point')
void wardrivingServiceStartCallback() {
  FlutterForegroundTask.setTaskHandler(_WardrivingTaskHandler());
}

/// No-op task handler; the service exists only to keep the process alive.
class _WardrivingTaskHandler extends TaskHandler {
  /// Called when the service starts; nothing to do.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  /// Unused: the service has no periodic work.
  @override
  void onRepeatEvent(DateTime timestamp) {}

  /// Called when the service stops; nothing to clean up.
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Android foreground service plus CPU wake lock that keeps recording alive.
class ForegroundBackgroundService implements BackgroundService {
  Timer? _notificationTimer;

  /// Configures the notification channel (Android only).
  @override
  Future<void> init() async {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _notificationChannelId,
        channelName: 'Wardriving Service',
        channelDescription: 'Shows live wardriving stats while recording.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
  }

  /// Acquires the wake lock, starts the service and refreshes its notification every second.
  @override
  Future<void> start(String Function() statusText) async {
    if (!Platform.isAndroid) return;
    await _powerChannel.invokeMethod<void>('acquireWakeLock');

    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'BNB Wardriving in progress',
      notificationText: statusText(),
      callback: wardrivingServiceStartCallback,
    );

    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      FlutterForegroundTask.updateService(notificationText: statusText());
    });
  }

  /// Stops the notification refresh, releases the wake lock and ends the service.
  @override
  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    _notificationTimer?.cancel();
    _notificationTimer = null;
    await _powerChannel.invokeMethod<void>('releaseWakeLock');
    await FlutterForegroundTask.stopService();
  }
}
