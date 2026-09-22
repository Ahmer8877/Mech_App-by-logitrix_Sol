import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cores/providers/notifications_provider.dart';
import '../cores/theme/app_theme.dart';

/// Notification Icon Button with real-time live badge counter for unread notifications
class NotificationIconButton extends ConsumerWidget {
  final VoidCallback onTap;

  const NotificationIconButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c.surface2,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 20,
              color: scheme.primary,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Amber "primary CTA" button — used for the main action on a screen
/// (Confirm, Next, Send Offer). Mirrors .cta in the HTML kit.
class AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;

  const AccentButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 14),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Teal "secondary CTA" — used for confirm/login actions. Mirrors .cta-primary.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 14),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Outlined button — mirrors .cta-outline. `isDanger` swaps the border/text red.
class OutlineActionButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final bool isDanger;
  final bool fullWidth;

  const OutlineActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isDanger = false,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = isDanger ? c.danger : Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: isDanger ? c.danger : c.borderStrong,
            width: 1.4,
          ),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              IconTheme.merge(
                data: const IconThemeData(size: 18),
                child: icon!,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill button used inline on cards (e.g. "Send Offer" on a request card).
class SmallAccentButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const SmallAccentButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
      ),
      child: Text(label),
    );
  }
}
