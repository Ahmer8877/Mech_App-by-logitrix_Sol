import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../cores/services/livekit_call_service.dart';
import '../../cores/utils/friendly_error.dart';
import '../../widgets/app_text.dart';

/// Read-only recent booking calls for the signed-in customer or mechanic.
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _calls = LiveKitCallService.instance;
  late Future<List<CallSession>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _calls.getCallHistory();
  }

  Future<void> _refresh() async {
    final next = _calls.getCallHistory();
    setState(() => _historyFuture = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder below displays the failure state.
    }
  }

  String _otherName(CallSession session, String currentUserId) {
    return currentUserId == session.callerId
        ? session.calleeName
        : session.callerName;
  }

  String _statusLabel(CallSession session, String currentUserId) {
    if (session.status == 'missed') {
      return currentUserId == session.calleeId
          ? 'Missed incoming call'
          : 'No answer';
    }
    if (session.status == 'rejected') {
      return currentUserId == session.callerId
          ? 'Call declined'
          : 'Declined call';
    }
    if (session.status == 'accepted' || session.status == 'ended') {
      return session.durationSeconds > 0 ? 'Completed call' : 'Call ended';
    }
    return session.status == 'ringing' ? 'Call interrupted' : session.status;
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Date unavailable';
    final local = date.toLocal();
    final dateText =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
    final timeText =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$dateText · $timeText';
  }

  String _durationLabel(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Call history'),
        actions: [
          IconButton(
            tooltip: 'Refresh call history',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: userId == null
          ? const Center(child: AppText('Please sign in to view call history.'))
          : FutureBuilder<List<CallSession>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // Keep the error state scrollable so pull-to-refresh works
                  // even when the first request failed (for example offline).
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 110),
                        const Icon(Icons.cloud_off_outlined, size: 40),
                        const SizedBox(height: 12),
                        const Center(
                          child: AppText('Could not load call history.'),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: AppText(
                            friendlyErrorMessage(snapshot.error!),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: FilledButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const AppText('Try again'),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final sessions = snapshot.data ?? const <CallSession>[];
                if (sessions.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        const SizedBox(height: 130),
                        const Icon(Icons.call, size: 48),
                        const SizedBox(height: 12),
                        const Center(child: AppText('No booking calls yet')),
                        const SizedBox(height: 8),
                        const Center(
                          child: AppText(
                            'When you make or receive a booking call, it will appear here.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const AppText('Refresh history'),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final outgoing = session.callerId == userId;
                      final name = _otherName(session, userId);
                      final status = _statusLabel(session, userId);
                      final missed =
                          session.status == 'missed' ||
                          session.status == 'rejected';
                      final icon = missed
                          ? Icons.call_missed_outgoing
                          : outgoing
                          ? Icons.call_made
                          : Icons.call_received;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            icon,
                            color: missed
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_dateLabel(session.createdAt)),
                            AppText(status),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (session.durationSeconds > 0)
                              Text(_durationLabel(session.durationSeconds)),
                            if (session.status != 'ringing')
                              const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
