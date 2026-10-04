import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/upload_result.dart';
import '../../domain/usecases/upload_recording.dart';

/// Per-service upload stage shown above the navigation bar; null when hidden.
class UploadProgressController extends ChangeNotifier
    implements UploadProgressListener {
  Map<String, UploadStage>? _stages;
  Timer? _hideTimer;

  /// Current stage of each service, or null when nothing is showing.
  Map<String, UploadStage>? get stages => _stages;

  /// Shows every service as waiting.
  @override
  void begin(List<String> services) {
    _hideTimer?.cancel();
    _stages = {for (final service in services) service: UploadStage.pending};
    notifyListeners();
  }

  /// Sets the stage of one service.
  @override
  void update(String service, UploadStage stage) {
    final current = _stages;
    if (current == null) return;
    _stages = {...current, service: stage};
    notifyListeners();
  }

  /// Hides the progress strip after a short delay.
  @override
  void finish() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      _stages = null;
      notifyListeners();
    });
  }

  /// Cancels the pending hide timer.
  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}
