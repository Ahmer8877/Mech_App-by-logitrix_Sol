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
  Stream<List<ChatMessageModel>> watchMessages(String bookingId) => client
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('booking_id', bookingId)
      .order('created_at')
      .map((rows) => rows.map((e) => ChatMessageModel.fromMap(e)).toList());

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
