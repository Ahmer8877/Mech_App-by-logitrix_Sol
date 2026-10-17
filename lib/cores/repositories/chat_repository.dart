import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';

/// Repository handling real-time chat messaging between Customer and Mechanic.
/// Connects to Supabase 'chat_messages' table to stream and send text messages.
/// Enforces participant access permissions via PostgreSQL RLS policies.
class ChatRepository {
  final SupabaseClient client;
  ChatRepository(this.client);

  /// Subscribes to real-time chat messages stream for a specific booking.
  /// Listens to PostgreSQL changes in 'chat_messages' table matching the booking ID.
  /// Converts raw database rows into strongly-typed ChatMessageModel instances.
  Stream<List<ChatMessageModel>> watchMessages(String bookingId) async* {
    if (bookingId.isEmpty) {
      yield const [];
      return;
    }

    final channel = client.channel('chat_messages:$bookingId');
    final controller = StreamController<List<ChatMessageModel>>();
    var disposed = false;

    Future<void> emitLatest() async {
      try {
        final rows = await client
            .from('chat_messages')
            .select()
            .eq('booking_id', bookingId)
            .order('created_at');
        if (!disposed) {
          controller.add(
            rows
                .map(
                  (e) => ChatMessageModel.fromMap(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false),
          );
        }
      } catch (e) {
        debugPrint('Chat history refresh error: $e');
      }
    }

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'booking_id',
        value: bookingId,
      ),
      callback: (_) => emitLatest(),
    );

    channel.subscribe();
    await emitLatest();

    try {
      yield* controller.stream;
    } finally {
      disposed = true;
      await channel.unsubscribe();
      await controller.close();
    }
  }

  Future<List<Map<String, dynamic>>> getHistoryForUser(String userId) async {
    if (userId.isEmpty) return const [];

    final bookings = await client
        .from('bookings')
        .select(
          'id,status,created_at,service_title,customer_id,mechanic_id,customer:profiles!bookings_customer_id_fkey(id,full_name),mechanic:profiles!bookings_mechanic_id_fkey(id,full_name)',
        )
        .or('customer_id.eq.$userId,mechanic_id.eq.$userId')
        .eq('status', 'completed')
        .order('created_at', ascending: false);

    final history = <Map<String, dynamic>>[];
    for (final row in (bookings as List)) {
      final booking = Map<String, dynamic>.from(row);
      final messages = await client
          .from('chat_messages')
          .select('message,created_at')
          .eq('booking_id', booking['id'])
          .order('created_at', ascending: false)
          .limit(1);
      if (messages.isEmpty) continue;

      final other = booking['customer_id'] == userId
          ? booking['mechanic']
          : booking['customer'];
      history.add({
        'booking_id': booking['id'],
        'service_title': booking['service_title'] ?? 'Service',
        'other_user_id': other is Map ? other['id']?.toString() ?? '' : '',
        'other_name': other is Map
            ? other['full_name']?.toString() ?? 'User'
            : 'User',
        'last_message': messages.first['message']?.toString() ?? '',
        'last_message_at': messages.first['created_at']?.toString(),
      });
    }
    return history;
  }

  /// Inserts a new chat message into the Supabase 'chat_messages' table.
  /// Requires valid bookingId, senderId (active user), and receiverId.
  /// Triggers real-time stream updates for both customer and mechanic chat screens.
  Future<void> send({
    required String bookingId,
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;
    await client.from('chat_messages').insert({
      'booking_id': bookingId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message.trim(),
    });
  }

  /// Marks all unread chat messages for a specific booking and receiver as read.
  /// Updates 'is_read' boolean to true in Supabase 'chat_messages' table.
  /// Resets unread chat badge counter on active map tracking screens.
  Future<void> markRead({
    required String bookingId,
    required String activeUserId,
  }) async {
    try {
      await client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('booking_id', bookingId)
          .eq('receiver_id', activeUserId)
          .eq('is_read', false);
    } catch (_) {}
  }
}
