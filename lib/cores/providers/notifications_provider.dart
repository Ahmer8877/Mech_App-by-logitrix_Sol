import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import 'auth_provider.dart';

/// Provider for accessing the NotificationRepository instance.
/// Connects directly to Supabase client to fetch, update, and delete notifications.
/// Used throughout the app by NotificationNotifier and notification widgets.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(supabase),
);

/// AsyncNotifier managing the active user's notifications state.
/// Automatically re-fetches notifications whenever the authenticated user ID changes.
/// Exposes actions to mark all notifications as read, delete single, or clear all notifications.
class NotificationsNotifier extends AsyncNotifier<List<NotificationModel>> {
  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  Future<List<NotificationModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));

    if (userId == null) return const [];

    return _repository.getForUser(userId);
  }

  /// Marks all unread notifications for the active user as read in Supabase.
  Future<void> markAllAsRead() async {
    final userId = ref.read(authProvider).user?.id;

    if (userId == null) return;

    await _repository.markAllRead(userId);

    ref.invalidateSelf();
    await future;
  }

  /// Deletes a single notification by ID for the active user from Supabase.
  Future<void> deleteNotification(String notificationId) async {
    final userId = ref.read(authProvider).user?.id;

    if (userId == null) return;

    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data(
      currentList.where((n) => n.id != notificationId).toList(),
    );

    try {
      await _repository.deleteSingle(notificationId, userId);
    } catch (_) {
      ref.invalidateSelf();
    }
  }

  /// Deletes all notification rows for the active user from Supabase.
  Future<void> clearAll() async {
    final userId = ref.read(authProvider).user?.id;

    if (userId == null) return;

    state = const AsyncValue.data([]);

    try {
      await _repository.clearAll(userId);
    } catch (_) {
      ref.invalidateSelf();
    }
  }
}

/// Provider supplying the real-time list of notification models for the active user.
final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
      NotificationsNotifier.new,
    );

/// Provider computing the unread notification count for the active user.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications =
      ref.watch(notificationsProvider).valueOrNull ??
      const <NotificationModel>[];

  return notifications.where((n) => n.unread).length;
});
