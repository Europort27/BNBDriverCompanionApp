import '../entities/wardriving_session.dart';

/// Persistent list of finished wardriving sessions.
abstract class HistoryRepository {
  /// Sessions in the order they were recorded (oldest first).
  Future<List<WardrivingSession>> loadAll();

  /// Appends a finished session.
  Future<void> add(WardrivingSession session);

  /// Replaces every stored session that has the same file name.
  Future<void> update(WardrivingSession session);
}
