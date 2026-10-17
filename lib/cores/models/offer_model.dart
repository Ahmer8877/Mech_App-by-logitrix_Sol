class Offer {
  final String id;
  final String bookingId;
  final String mechanicId;
  final String mechanicName;
  final double mechanicRating;
  final double price;
  final String estimatedTime;
  final String? message;
  final String status;

  const Offer({
    required this.id,
    required this.bookingId,
    required this.mechanicId,
    required this.mechanicName,
    required this.mechanicRating,
    required this.price,
    required this.estimatedTime,
    this.message,
    required this.status,
  });

  factory Offer.fromMap(Map<String, dynamic> map) {
    final mechanic = map['mechanic'];
    return Offer(
      id: map['id']?.toString() ?? '',
      bookingId: map['booking_id']?.toString() ?? '',
      mechanicId: map['mechanic_id']?.toString() ?? '',
      mechanicName: mechanic is Map
          ? mechanic['full_name']?.toString() ?? 'Mechanic'
          : 'Mechanic',
      mechanicRating: mechanic is Map
          ? (mechanic['rating'] as num?)?.toDouble() ?? 0
          : 0,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      estimatedTime: map['estimated_time']?.toString() ?? '',
      message: map['message']?.toString(),
      status: map['status']?.toString() ?? 'pending',
    );
  }
}
