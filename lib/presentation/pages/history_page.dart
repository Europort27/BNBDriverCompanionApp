import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/entities/wardriving_session.dart';
import '../controllers/history_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/debug_badge.dart';

/// Lists past sessions with per-service upload status and retry.
class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.controller,
    required this.settings,
  });

  final HistoryController controller;
  final SettingsController settings;

  /// Creates the page state.
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

/// Loads history when the page opens.
class _HistoryPageState extends State<HistoryPage> {
  HistoryController get _controller => widget.controller;

  /// Loads the history.
  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  /// Retries the failed upload(s) and shows the resulting message.
  Future<void> _resubmit(
    WardrivingSession session, {
    required bool wdgwars,
    required bool wardrift,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await _controller.resubmit(
      session,
      wdgwars: wdgwars,
      wardrift: wardrift,
    );
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// One service's upload status; tapping a failed one retries it.
  Widget _serviceStatusTile({
    required String label,
    required bool succeeded,
    required bool retrying,
    required VoidCallback onRetry,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(
        succeeded ? Icons.check_circle_outline : Icons.highlight_off,
        color: succeeded ? colors.tertiary : colors.secondary,
      ),
      title: Text(label),
      subtitle: Text(succeeded ? 'Uploaded' : 'Failed - tap to retry'),
      trailing: succeeded
          ? null
          : retrying
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      onTap: succeeded || retrying ? null : onRetry,
    );
  }

  /// Expandable card for one session.
  Widget _sessionCard(WardrivingSession session) {
    final colors = Theme.of(context).colorScheme;
    final retrying = _controller.isRetrying(session.fileName);
    final allSucceeded =
        (!_controller.showWdgwars || session.uploadedToWdgwars) &&
        (!_controller.showWardrift || session.uploadedToWardrift);
    return Card(
      child: ExpansionTile(
        childrenPadding: const EdgeInsets.only(left: 32),
        leading: Icon(
          allSucceeded ? Icons.check_circle_outline : Icons.highlight_off,
          color: allSucceeded ? colors.tertiary : colors.secondary,
        ),
        title: Text(session.fileName),
        subtitle: Text(
          '${session.uniqueAccessPoints} unique APs  |  '
          '${session.uniqueBluetoothIds} unique BT IDs  |  '
          '${formatCompactDuration(session.durationSeconds)}  |  '
          '${formatMiles(session.distanceMeters)}',
        ),
        children: [
          if (_controller.showWdgwars)
            _serviceStatusTile(
              label: 'WDGWars',
              succeeded: session.uploadedToWdgwars,
              retrying: retrying,
              onRetry: () => _resubmit(session, wdgwars: true, wardrift: false),
            ),
          if (_controller.showWardrift)
            _serviceStatusTile(
              label: 'Wardrift',
              succeeded: session.uploadedToWardrift,
              retrying: retrying,
              onRetry: () => _resubmit(session, wdgwars: false, wardrift: true),
            ),
          if (!_controller.showWdgwars && !_controller.showWardrift)
            const ListTile(
              dense: true,
              title: Text('No upload API keys configured'),
            ),
        ],
      ),
    );
  }

  /// Builds the session list, or a loading/empty state.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          DebugBadge(settings: widget.settings),
          const SizedBox(width: 12),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.sessions.isEmpty) {
            return const Center(child: Text('No wardriving sessions yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _controller.sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _sessionCard(_controller.sessions[index]),
          );
        },
      ),
    );
  }
}
