import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupportRepository {
  const SupportRepository();

  Future<Map<String, dynamic>> getOrCreateConversation(String userId) async {
    if (userId.isEmpty) throw Exception('User session not found.');
    final existing = await supabase
        .from('support_conversations')
        .select('id,status')
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) return Map<String, dynamic>.from(existing);

    await supabase.from('support_conversations').insert({'user_id': userId});
    final created = await supabase
        .from('support_conversations')
        .select('id,status')
        .eq('user_id', userId)
        .single();
    return Map<String, dynamic>.from(created);
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    if (conversationId.isEmpty) return Stream.value(const []);
    final controller = StreamController<List<Map<String, dynamic>>>();
    final channel = supabase.channel('support-chat:$conversationId');
    var disposed = false;

    Future<void> load() async {
      try {
        final rows = await supabase
            .from('support_messages')
            .select('id,sender_id,sender_role,message,is_read,created_at')
            .eq('conversation_id', conversationId)
            .order('created_at');
        if (!disposed) {
          controller.add(List<Map<String, dynamic>>.from(rows));
        }
      } catch (e) {
        debugPrint('Support chat refresh error: $e');
      }
    }

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (_) => load(),
    );
    channel.subscribe();
    load();

    controller.onCancel = () async {
      disposed = true;
      await channel.unsubscribe();
    };
    return controller.stream;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String message,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || message.trim().isEmpty) return;
    await supabase.from('support_messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'sender_role': 'user',
      'message': message.trim(),
    });
  }
}
