import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';

import '../../cores/theme/app_theme.dart';

/// Simple in-app "calling" screen mockup — shown when the customer taps
/// Call on a mechanic (or vice versa). Simulates ringing → connected state.
/// No real VoIP backend wired up; swap the timer logic for actual call
/// signaling (Twilio/Agora/etc.) when the backend is ready.
class CallScreen extends StatefulWidget {
  final String name;
  final String initials;
  final String subtitle;

  const CallScreen({
    super.key,
    required this.name,
    required this.initials,
    this.subtitle = 'Mobile',
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _connected = false;
  bool _muted = false;
  bool _speaker = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _connected = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _durationLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
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
                child: AppText(
                  widget.initials,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimary,
                  ),
                ),
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
                _connected ? _durationLabel : 'Calling ${widget.subtitle}...',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.7),
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundButton(
                    icon: _muted ? Icons.mic_off : Icons.mic_none,
                    active: _muted,
                    onTap: () => setState(() => _muted = !_muted),
                  ),
                  _RoundButton(
                    icon: _speaker ? Icons.volume_up : Icons.volume_up_outlined,
                    active: _speaker,
                    onTap: () => setState(() => _speaker = !_speaker),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: c.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
  final VoidCallback onTap;
  const _RoundButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: active
              ? scheme.onPrimary
              : scheme.onPrimary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: active ? context.colors.primaryStrong : scheme.onPrimary,
          size: 22,
        ),
      ),
    );
  }
}
