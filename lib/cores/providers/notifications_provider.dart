import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import 'auth_provider.dart';

/// Provider for accessing the NotificationRepository instance.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(supabase),
);

/// Real-time stream provider for the active user's notifications.
final notificationsStreamProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
      if (userId.isEmpty) return Stream.value(const []);
      return ref.read(notificationRepositoryProvider).watchForUser(userId);
    });

/// Reactive provider supplying the real-time AsyncValue notification list for the active user.
final notificationsProvider = Provider<AsyncValue<List<NotificationModel>>>((
  ref,
) {
  final userId =
      ref.watch(authProvider.select((state) => state.user?.id)) ?? '';
  if (userId.isEmpty) return const AsyncValue.data([]);
  return ref.watch(notificationsStreamProvider(userId));
});

/// Provider computing the unread notification count for the active user in real-time.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications =
      ref.watch(notificationsProvider).valueOrNull ??
      const <NotificationModel>[];

  return notifications.where((n) => n.unread).length;
});

/// Controller managing notification mutation actions (mark read, delete, clear).
class NotificationsController {
  final NotificationRepository _repository;
  final Ref _ref;

  NotificationsController(this._repository, this._ref);

  /// Marks all unread notifications for the active user as read in Supabase.
  Future<void> markAllAsRead() async {
    final userId = _ref.read(authProvider).user?.id;
    if (userId == null) return;
    await _repository.markAllRead(userId);
    _ref.invalidate(notificationsStreamProvider(userId));
  }

  /// Deletes a single notification by ID for the active user from Supabase.
  Future<void> deleteNotification(String notificationId) async {
    final userId = _ref.read(authProvider).user?.id;
    if (userId == null) return;
    await _repository.deleteSingle(notificationId, userId);
    _ref.invalidate(notificationsStreamProvider(userId));
  }

  /// Deletes all notification rows for the active user from Supabase.
  Future<void> clearAll() async {
    final userId = _ref.read(authProvider).user?.id;
    if (userId == null) return;
    await _repository.clearAll(userId);
    _ref.invalidate(notificationsStreamProvider(userId));
  }
}

final notificationsControllerProvider = Provider((ref) {
  return NotificationsController(ref.read(notificationRepositoryProvider), ref);
});
