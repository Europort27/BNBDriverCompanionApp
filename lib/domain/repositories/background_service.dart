/// Keeps the app alive and visible (wake lock + notification) while recording.
abstract class BackgroundService {
  /// Prepares the notification channel; call once at startup.
  Future<void> init();

  /// Starts background mode; [statusText] is polled for the notification text.
  Future<void> start(String Function() statusText);

  /// Ends background mode and releases the wake lock.
  Future<void> stop();
}
