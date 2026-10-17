class ChatMessageModel {
  final String id;
  final String bookingId;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime? createdAt;
  final bool isRead;
  const ChatMessageModel({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.createdAt,
    this.isRead = false,
  });
  factory ChatMessageModel.fromMap(Map<String, dynamic> map) =>
      ChatMessageModel(
        id: map['id']?.toString() ?? '',
        bookingId: map['booking_id']?.toString() ?? '',
        senderId: map['sender_id']?.toString() ?? '',
        receiverId: map['receiver_id']?.toString() ?? '',
        message: map['message']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
        isRead: map['is_read'] as bool? ?? false,
      );
}
