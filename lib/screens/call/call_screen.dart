import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../cores/services/livekit_call_service.dart';
import '../../cores/utils/friendly_error.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_text.dart';

/// Real MechX booking voice call screen backed by LiveKit.
/// Support's old static call entry is intentionally kept separate.
class CallScreen extends StatefulWidget {
  final String name;
  final String initials;
  final String? bookingId;
  final bool incoming;
  final String? sessionId;
  final String subtitle;
  final String? avatarUrl;

  const CallScreen({
    super.key,
    required this.name,
    required this.initials,
    this.bookingId,
    this.incoming = false,
    this.sessionId,
    this.subtitle = 'Mobile',
    this.avatarUrl,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  final _calls = LiveKitCallService.instance;
  CallSession? _session;
  Room? _room;
  StreamSubscription<CallSession>? _sessionSubscription;
  Timer? _durationTimer;
  Timer? _ringTimeoutTimer;
  Timer? _incomingRingTimer;
  static const MethodChannel _incomingRingtoneChannel = MethodChannel(
    'com.mechx.app/incoming_ringtone',
  );
  bool _customRingtoneAvailable = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  dynamic _roomListener;
  bool _connecting = false;
  bool _accepting = false;
  bool _connected = false;
  bool _muted = false;
  bool _speaker = false;
  bool _closing = false;
  bool _endRequested = false;
  bool _networkIssue = false;
  bool _isReconnecting = false;
  bool _hasConnectedOnce = false;
  bool _autoRejoinAttempted = false;
  final Set<String> _poorQualityParticipantIds = <String>{};
  int _seconds = 0;
  String? _error;
  String? _resolvedAvatarUrl;

  Future<void> _loadOtherParticipantAvatar() async {
    final explicit = widget.avatarUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      _resolvedAvatarUrl = explicit;
      return;
    }
    final session = _session;
    if (session == null) return;
    try {
      final avatar = await _calls.getOtherParticipantAvatarUrl(
        callerId: session.callerId,
        calleeId: session.calleeId,
      );
      if (avatar != null && avatar.trim().isNotEmpty) {
        _resolvedAvatarUrl = avatar.trim();
      }
    } catch (_) {
      // Avatar is optional; a failed profile lookup must not block the call.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.bookingId == null || widget.bookingId!.isEmpty) {
        // Preserve the existing support-call experience. Only booking calls
        // use LiveKit.
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        setState(() => _connected = true);
        _startDuration();
        return;
      }
      if (widget.incoming) {
        if (widget.sessionId == null || widget.sessionId!.isEmpty) {
          throw StateError('Incoming call session is missing.');
        }
        _session = await _calls.getSession(widget.sessionId!);
        await _loadOtherParticipantAvatar();
        if (!mounted) return;
        _listenForIncomingState();
        setState(() {});
        if (_session?.status == 'ringing') {
          _startIncomingRinging();
        }
        if (_session?.status == 'accepted') {
          await _connectToRoom();
        } else if (_isClosedStatus(_session?.status)) {
          _showClosedCallMessage(_session!.status);
        }
        return;
      }

      _session = await _calls.startCall(bookingId: widget.bookingId!);
      // End may be tapped while startCall() is still creating the server
      // session. Remember that intent and close the session immediately when
      // its ID arrives, rather than leaving a live ringing call behind.
      if (_endRequested) {
        await _closeCreatedOutgoingCall();
        return;
      }
      await _loadOtherParticipantAvatar();
      if (!mounted) return;
      if (_endRequested) {
        await _closeCreatedOutgoingCall();
        return;
      }
      _listenForAcceptedState();
      if (mounted) setState(() {});
      if (_session?.status == 'accepted') {
        await _connectToRoom();
      } else if (_session?.status == 'ringing') {
        _startRingTimeout();
      }
    } catch (e) {
      if (!mounted) return;
      if (_endRequested) {
        _closing = true;
        await _calls.disconnect(_room);
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      setState(() => _error = friendlyErrorMessage(e));
    }
  }

  void _listenForAcceptedState() {
    final session = _session;
    if (session == null) return;
    _sessionSubscription?.cancel();
    _sessionSubscription = _calls
        .watchSession(session.id)
        .listen(
          (updated) {
            if (!mounted) return;
            _session = updated;
            debugPrint('MechX call ${updated.id} state: ${updated.status}');

            if (updated.status == 'accepted' &&
                !_connected &&
                !_closing &&
                !_endRequested) {
              _ringTimeoutTimer?.cancel();
              _connectToRoom();
            } else if (_isClosedStatus(updated.status)) {
              _ringTimeoutTimer?.cancel();
              _showClosedCallMessage(updated.status);
            } else {
              setState(() {});
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            // Realtime status is separate from the LiveKit audio connection. A
            // temporary Supabase stream error must not mark an already-connected
            // voice call as unavailable or bring back the Retry action.
            if (!_connected && !_connecting) {
              setState(
                () => _error =
                    'Call status temporarily unavailable. Check your connection.',
              );
            }
            debugPrint('MechX call status stream error: $error');
          },
        );
  }

  void _listenForIncomingState() {
    final session = _session;
    if (session == null) return;
    _sessionSubscription?.cancel();
    _sessionSubscription = _calls
        .watchSession(session.id)
        .listen(
          (updated) {
            if (!mounted) return;
            _session = updated;
            debugPrint(
              'MechX incoming call ${updated.id} state: ${updated.status}',
            );
            _syncIncomingRinging(updated.status);

            if (updated.status == 'accepted' &&
                !_connected &&
                !_connecting &&
                !_accepting &&
                !_closing) {
              _connectToRoom();
            } else if (_isClosedStatus(updated.status)) {
              _showClosedCallMessage(updated.status);
            } else {
              setState(() {});
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            // Do not replace a healthy LiveKit call UI with a Realtime warning.
            if (!_connected && !_connecting) {
              setState(
                () => _error =
                    'Call status temporarily unavailable. Check your connection.',
              );
            }
            debugPrint('MechX incoming-call status stream error: $error');
          },
        );
  }

  /// Keeps the incoming-call alert active while the app is in the foreground.
  /// When the app is backgrounded, the OS-level OneSignal notification owns
  /// alerting; this timer is deliberately stopped to avoid background timers.
  void _startIncomingRinging() {
    if (!widget.incoming ||
        _session?.status != 'ringing' ||
        _lifecycleState != AppLifecycleState.resumed ||
        _closing) {
      return;
    }
    if (_incomingRingTimer?.isActive ?? false) return;

    // Start the dedicated MechX ringtone on Android. Platforms without the
    // native channel fall back to the system alert without affecting calls.
    _startCustomIncomingRingtone();
    _playIncomingAlert();
    _incomingRingTimer = Timer.periodic(const Duration(milliseconds: 2200), (
      _,
    ) {
      if (!mounted ||
          _closing ||
          _session?.status != 'ringing' ||
          _lifecycleState != AppLifecycleState.resumed) {
        _stopIncomingRinging();
        return;
      }
      _playIncomingAlert();
    });
  }

  Future<void> _startCustomIncomingRingtone() async {
    try {
      await _incomingRingtoneChannel.invokeMethod<void>('start');
      if (!mounted ||
          _closing ||
          _session?.status != 'ringing' ||
          _lifecycleState != AppLifecycleState.resumed) {
        await _incomingRingtoneChannel.invokeMethod<void>('stop');
        return;
      }
      _customRingtoneAvailable = true;
    } on PlatformException catch (error) {
      _customRingtoneAvailable = false;
      debugPrint('MechX ringtone could not start: ${error.message}');
    } on MissingPluginException {
      _customRingtoneAvailable = false;
    }
  }

  void _playIncomingAlert() {
    if (_lifecycleState != AppLifecycleState.resumed || _closing) return;
    if (!_customRingtoneAvailable) {
      SystemSound.play(SystemSoundType.alert);
    }
    HapticFeedback.vibrate();
  }

  void _stopIncomingRinging() {
    _incomingRingTimer?.cancel();
    _incomingRingTimer = null;
    _customRingtoneAvailable = false;
    _incomingRingtoneChannel.invokeMethod<void>('stop').catchError((
      Object error,
    ) {
      debugPrint('Could not stop MechX ringtone: $error');
    });
  }

  void _syncIncomingRinging(String? status) {
    if (status == 'ringing') {
      _startIncomingRinging();
    } else {
      _stopIncomingRinging();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      if (widget.incoming && _session?.status == 'ringing') {
        _startIncomingRinging();
        final id = _session?.id;
        if (id != null) {
          _calls
              .getSession(id)
              .then((latest) {
                if (!mounted || _closing) return;
                _session = latest;
                _syncIncomingRinging(latest.status);
                if (latest.status == 'accepted' &&
                    !_connected &&
                    !_connecting) {
                  _connectToRoom();
                } else if (_isClosedStatus(latest.status)) {
                  _showClosedCallMessage(latest.status);
                } else {
                  setState(() {});
                }
              })
              .catchError((Object error) {
                debugPrint(
                  'Could not refresh incoming call after resume: $error',
                );
              });
        }
      }
    } else {
      _stopIncomingRinging();
    }
  }

  Future<void> _accept() async {
    _stopIncomingRinging();
    final session = _session;
    if (session == null || _accepting || _connecting || _connected) return;

    setState(() => _accepting = true);
    try {
      final acceptedSession = await _calls.acceptCall(session.id);
      if (!mounted) return;
      _session = acceptedSession;
      setState(() => _accepting = false);

      // The accept response is authoritative for this screen. A realtime
      // event may arrive before or after it, but _connectToRoom() is guarded
      // so only one LiveKit connection can be created.
      if (acceptedSession.status == 'accepted') {
        await _connectToRoom();
      } else if (_isClosedStatus(acceptedSession.status)) {
        _showClosedCallMessage(acceptedSession.status);
      }
    } catch (e) {
      // A simultaneous realtime update can make the accept request appear
      // stale. Refresh the authoritative state and continue if it was accepted.
      try {
        final latest = await _calls.getSession(session.id);
        if (latest.status == 'accepted') {
          _session = latest;
          if (mounted) setState(() => _accepting = false);
          await _connectToRoom();
          return;
        }
      } catch (_) {
        // Keep the original failure below for display.
      }
      if (mounted) {
        setState(() {
          _accepting = false;
          _error = friendlyErrorMessage(e);
        });
      }
    } finally {
      if (mounted && _accepting) setState(() => _accepting = false);
    }
  }

  Future<void> _connectToRoom() async {
    if (!mounted || _connected || _connecting || _session == null) return;

    setState(() {
      _connecting = true;
      _error = null;
    });
    _ringTimeoutTimer?.cancel();
    try {
      final session = _session!;
      debugPrint(
        'MechX connecting call session: ${session.id} (${session.status})',
      );

      final credentials = await _calls.getCredentials(sessionId: session.id);
      final room = await _calls.connect(
        credentials.serverUrl,
        credentials.participantToken,
      );

      _room = room;
      _connected = true;
      _networkIssue = false;
      _error = null;
      if (!_hasConnectedOnce) {
        _seconds = 0;
        _hasConnectedOnce = true;
      }
      _listenForRoomConnection(room);
      _startDuration();

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      } else {
        _connecting = false;
      }
    }
  }

  void _startDuration() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Match the connected-time clock in WhatsApp: time pauses while the
      // media connection is recovering and resumes only after reconnection.
      if (!mounted || !_connected || _networkIssue || _closing) return;
      setState(() => _seconds++);
    });
  }

  void _pauseDurationForNetworkIssue() {
    if (!mounted || _closing) return;
    if (!_networkIssue) setState(() => _networkIssue = true);
    _durationTimer?.cancel();
  }

  void _resumeDurationAfterNetworkRecovery() {
    if (!mounted || _closing || _isReconnecting) return;
    if (_poorQualityParticipantIds.isNotEmpty) {
      _pauseDurationForNetworkIssue();
      return;
    }
    setState(() {
      _networkIssue = false;
      _connected = true;
      _error = null;
    });
    _startDuration();
  }

  void _listenForRoomConnection(Room room) {
    try {
      (_roomListener as dynamic)?.dispose();
    } catch (_) {}
    final listener = room.createListener();
    _roomListener = listener;
    listener
      ..on<RoomReconnectingEvent>((_) {
        _isReconnecting = true;
        _pauseDurationForNetworkIssue();
      })
      ..on<RoomResumingEvent>((_) {
        _isReconnecting = true;
        _pauseDurationForNetworkIssue();
      })
      ..on<RoomAttemptReconnectEvent>((_) {
        _isReconnecting = true;
        _pauseDurationForNetworkIssue();
      })
      ..on<RoomReconnectedEvent>((_) {
        _isReconnecting = false;
        _resumeDurationAfterNetworkRecovery();
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        final participantId = event.participant.identity;
        if (event.connectionQuality == ConnectionQuality.poor ||
            event.connectionQuality == ConnectionQuality.lost) {
          _poorQualityParticipantIds.add(participantId);
          _pauseDurationForNetworkIssue();
        } else {
          _poorQualityParticipantIds.remove(participantId);
          _resumeDurationAfterNetworkRecovery();
        }
      })
      ..on<RoomDisconnectedEvent>((_) {
        // A successful SDK reconnect emits RoomReconnectedEvent. A terminal
        // disconnect means SDK retries ended, so make one automatic fresh
        // room attempt; if that fails, expose the existing manual Retry action.
        if (_closing || !mounted) return;
        _isReconnecting = false;
        _durationTimer?.cancel();
        setState(() {
          _connected = false;
          _networkIssue = false;
          _error = 'Connection lost. Trying to reconnect…';
        });
        if (!_autoRejoinAttempted && _session?.status == 'accepted') {
          _autoRejoinAttempted = true;
          Future<void>.delayed(const Duration(seconds: 2), () async {
            if (!mounted || _closing || _connected || _connecting) return;
            if (_session?.status != 'accepted') return;
            if (mounted) setState(() => _error = null);
            await _connectToRoom();
          });
        }
      });
  }

  Future<void> _closeCreatedOutgoingCall() async {
    _closing = true;
    _durationTimer?.cancel();
    final id = _session?.id;
    if (id != null) {
      try {
        await _calls.endCall(id);
      } catch (e) {
        debugPrint('Could not cancel just-created call session: $e');
      }
    }
    _ringTimeoutTimer?.cancel();
    await _calls.disconnect(_room);
    if (mounted) Navigator.of(context).maybePop();
  }

  void _startRingTimeout() {
    _ringTimeoutTimer?.cancel();
    final sessionId = _session?.id;
    if (sessionId == null || widget.incoming) return;
    _ringTimeoutTimer = Timer(const Duration(seconds: 45), () async {
      if (!mounted || _connected || _session?.status != 'ringing') return;
      try {
        final latest = await _calls.markMissed(sessionId);
        if (!mounted) return;
        _session = latest;
        if (latest.status == 'accepted') {
          await _connectToRoom();
        } else if (latest.status == 'missed') {
          _showClosedCallMessage('missed');
        }
      } catch (e) {
        debugPrint('MechX ring timeout update failed: $e');
      }
    });
  }

  bool _isClosedStatus(String? status) =>
      status == 'rejected' || status == 'ended' || status == 'missed';

  void _showClosedCallMessage(String status) {
    if (!mounted || _closing) return;
    _stopIncomingRinging();
    _closing = true;
    final message = status == 'missed'
        ? 'No answer'
        : status == 'rejected'
        ? 'Call declined'
        : 'Call ended';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: AppText(message)));
    Navigator.of(context).maybePop();
  }

  Future<void> _reject() async {
    if (_closing) return;
    _stopIncomingRinging();
    _closing = true;
    final id = _session?.id;
    try {
      if (id != null) await _calls.rejectCall(id);
    } catch (e) {
      if (mounted) {
        _closing = false;
        setState(() => _error = friendlyErrorMessage(e));
        _syncIncomingRinging(_session?.status);
      }
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _end() async {
    if (_closing || _endRequested) return;
    _stopIncomingRinging();
    final id = _session?.id;
    if (id == null && widget.bookingId != null && !widget.incoming) {
      // startCall() is in flight; keep the screen alive until its response
      // gives us the session ID, then immediately end it server-side.
      setState(() {
        _endRequested = true;
        _error = null;
      });
      return;
    }

    _closing = true;
    _durationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    try {
      if (id != null) await _calls.endCall(id);
    } catch (e) {
      debugPrint('MechX end-call request failed: $e');
    } finally {
      try {
        (_roomListener as dynamic)?.dispose();
      } catch (_) {}
      await _calls.disconnect(_room);
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _toggleMute() async {
    final room = _room;
    if (room == null) return;
    final value = !_muted;
    await room.localParticipant?.setMicrophoneEnabled(!value);
    if (mounted) setState(() => _muted = value);
  }

  Future<void> _toggleSpeaker() async {
    final room = _room;
    if (room == null) return;
    final value = !_speaker;
    await AudioManager.instance.setSpeakerOutputPreferred(value);
    if (mounted) setState(() => _speaker = value);
  }

  String get _durationLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSubscription?.cancel();
    _durationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _stopIncomingRinging();
    try {
      (_roomListener as dynamic)?.dispose();
    } catch (_) {}
    _calls.disconnect(_room);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;

    // Show Accept/Reject only while the call is genuinely ringing.
    // Once Accept has been pressed, the UI switches to Connecting...
    // instead of leaving the incoming-call buttons on screen.
    final showIncomingActions =
        widget.incoming &&
        !_connected &&
        !_connecting &&
        !_accepting &&
        _session?.status == 'ringing';

    // A successful LiveKit connection always takes precedence over an old
    // status-stream error. This prevents a stale 'Call unavailable' label.
    final status = _networkIssue
        ? 'Poor connection · Unstable network. Reconnecting…'
        : _connected
        ? _durationLabel
        : _error != null
        ? 'Call unavailable'
        : _connecting
        ? 'Connecting...'
        : showIncomingActions
        ? 'Incoming call'
        : _endRequested
        ? 'Ending call…'
        : _session?.status == 'accepted'
        ? 'Connecting...'
        : 'Calling...';

    return Scaffold(
      backgroundColor: c.primaryStrong,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 30),
              CircleAvatar(
                radius: 46,
                backgroundColor: scheme.onPrimary.withValues(alpha: 0.15),
                backgroundImage: _resolvedAvatarUrl != null
                    ? CachedNetworkImageProvider(_resolvedAvatarUrl!)
                    : null,
                child: _resolvedAvatarUrl == null
                    ? AppText(
                        widget.initials,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              AppText(
                widget.name,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                status,
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.7),
                  fontSize: 12.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (_error != null && !_connected) ...[
                const SizedBox(height: 12),
                AppText(
                  _error!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null &&
                  !_connected &&
                  _session?.status == 'accepted' &&
                  !_connecting) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _networkIssue = false;
                    });
                    _connectToRoom();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const AppText('Retry connection'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimary,
                  ),
                ),
              ],
              const Spacer(),
              if (showIncomingActions) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundButton(
                      icon: Icons.call_end,
                      active: true,
                      background: c.danger,
                      onTap: _reject,
                    ),
                    _RoundButton(
                      icon: Icons.call,
                      active: true,
                      background: Colors.green,
                      onTap: _accept,
                    ),
                  ],
                ),
              ] else if (_connected) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundButton(
                      icon: _muted ? Icons.mic_off : Icons.mic_none,
                      active: _muted,
                      onTap: _toggleMute,
                    ),
                    _RoundButton(
                      icon: Icons.volume_up_outlined,
                      active: _speaker,
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _RoundButton(
                  icon: Icons.call_end,
                  active: true,
                  background: c.danger,
                  onTap: _end,
                ),
              ] else ...[
                _RoundButton(
                  icon: Icons.call_end,
                  active: true,
                  background: c.danger,
                  onTap: _end,
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color? background;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.active,
    this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color:
              background ??
              (active
                  ? scheme.onPrimary
                  : scheme.onPrimary.withValues(alpha: 0.15)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: background != null
              ? Colors.white
              : (active ? context.colors.primaryStrong : scheme.onPrimary),
          size: 25,
        ),
      ),
    );
  }
}
