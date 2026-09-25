import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/models/notification_model.dart';
import '../../cores/providers/notifications_provider.dart';
import '../../cores/theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _confirmDeleteSingle(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Notification?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${notification.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(notificationsControllerProvider)
          .deleteNotification(notification.id);
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Clear All Notifications?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(notificationsControllerProvider).clearAll();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifications = notificationsAsync.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontSize: 15)),
        actions: [
          if (notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all, size: 20),
              tooltip: 'Mark all as read',
              onPressed: () =>
                  ref.read(notificationsControllerProvider).markAllAsRead(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Clear all notifications',
              onPressed: () => _confirmClearAll(context, ref),
            ),
          ],
        ],
      ),
      body: notificationsAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notificationsAsync.hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Failed to load notifications.'),
                  TextButton(
                    onPressed: () => ref.invalidate(notificationsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : notifications.isEmpty
          ? Center(
              child: Text(
                'No notifications',
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = notifications[i];
                return Dismissible(
                  key: Key(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) {
                    ref
                        .read(notificationsControllerProvider)
                        .deleteNotification(n.id);
                  },
                  child: InkWell(
                    onLongPress: () => _confirmDeleteSingle(context, ref, n),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: n.unread
                            ? scheme.primary.withValues(alpha: 0.06)
                            : null,
                        border: Border.all(
                          color: c.borderStrong.withValues(alpha: 0.35),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c.surface2,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              n.icon,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  n.subtitle,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n.time,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (n.unread)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: c.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey,
                            ),
                            tooltip: 'Delete notification',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                _confirmDeleteSingle(context, ref, n),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
