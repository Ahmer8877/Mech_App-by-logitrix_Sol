import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository(supabase));

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageModel>, String>(
      (ref, bookingId) =>
          ref.read(chatRepositoryProvider).watchMessages(bookingId),
    );

/// Provider computing unread chat message count for a specific booking and user.
/// Watches real-time chatMessagesProvider stream and filters for unread messages sent to active user.
/// Watched by TrackingScreen and OnTheWayScreen to display live unread chat badge counters.
final unreadBookingChatCountProvider =
    Provider.family<int, ({String bookingId, String activeUserId})>((ref, arg) {
  if (arg.bookingId.isEmpty || arg.activeUserId.isEmpty) return 0;
  final messages = ref.watch(chatMessagesProvider(arg.bookingId)).valueOrNull ?? [];
  return messages.where((m) => m.receiverId == arg.activeUserId && !m.isRead).length;
});
