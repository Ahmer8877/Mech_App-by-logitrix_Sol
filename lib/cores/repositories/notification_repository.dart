import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient client;
  NotificationRepository(this.client);

  Future<List<NotificationModel>> getForUser(String userId) async {
    final rows = await client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => NotificationModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markAllRead(String userId) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> deleteSingle(String notificationId, String userId) async {
    await client
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }

  Future<void> clearAll(String userId) async {
    await client
        .from('notifications')
        .delete()
        .eq('user_id', userId);
  }
}
