class Booking {
  final String id;
  final String service;
  final String mechanic;
  final double mechanicRating;
  final String customer;
  final String address;
  final DateTime? createdAt;
  final double price;
  final String status;
  final bool completed;

  const Booking({
    required this.id,
    required this.service,
    required this.mechanic,
    this.mechanicRating = 0.0,
    this.customer = 'Customer',
    this.address = '',
    this.createdAt,
    this.price = 0,
    this.status = 'pending',
    this.completed = false,
  });

  static double _parseRating(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? 0.0;
    }
    return 0.0;
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    final status = map['status']?.toString() ?? 'pending';
    final mechanicData = map['mechanic'];
    final customerData = map['customer'];
    final serviceData = map['service'];
    return Booking(
      id: map['id']?.toString() ?? '',
      service:
          map['service_title']?.toString() ??
          (serviceData is Map
              ? serviceData['title']?.toString() ?? 'Service'
              : 'Service'),
      mechanic: mechanicData is Map
          ? mechanicData['full_name']?.toString() ?? 'Not assigned'
          : 'Not assigned',
      mechanicRating: mechanicData is Map
          ? _parseRating(mechanicData['rating'])
          : 0.0,
      customer: customerData is Map
          ? customerData['full_name']?.toString() ?? 'Customer'
          : 'Customer',
      address: map['pickup_address']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      price:
          ((map['agreed_price'] ?? map['budget_price']) as num?)?.toDouble() ??
          0,
      status: status,
      completed: status == 'completed',
    );
  }
}
