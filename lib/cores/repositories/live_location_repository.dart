import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveLocation {
  final String bookingId;
  final String? mechanicId;
  final double? latitude;
  final double? longitude;
  final double heading;
  final String? customerId;
  final double? customerLatitude;
  final double? customerLongitude;
  final double customerHeading;
  final DateTime? updatedAt;

  const LiveLocation({
    required this.bookingId,
    this.mechanicId,
    this.latitude,
    this.longitude,
    this.heading = 0,
    this.customerId,
    this.customerLatitude,
    this.customerLongitude,
    this.customerHeading = 0,
    this.updatedAt,
  });

  factory LiveLocation.fromMap(Map<String, dynamic> map) {
    return LiveLocation(
      bookingId: map['booking_id'].toString(),
      mechanicId: map['mechanic_id']?.toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble() ?? 0,
      customerId: map['customer_id']?.toString(),
      customerLatitude: (map['customer_latitude'] as num?)?.toDouble(),
      customerLongitude: (map['customer_longitude'] as num?)?.toDouble(),
      customerHeading: (map['customer_heading'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  bool get hasMechanicLocation => latitude != null && longitude != null;
  bool get hasCustomerLocation =>
      customerLatitude != null && customerLongitude != null;
}

class LiveLocationRepository {
  final SupabaseClient client;
  LiveLocationRepository(this.client);

  Stream<LiveLocation?> watchBookingLocation(String bookingId) {
    return client
        .from('booking_locations')
        .stream(primaryKey: ['booking_id'])
        .eq('booking_id', bookingId)
        .map(
          (rows) => rows.isEmpty
          ? null
          : LiveLocation.fromMap(Map<String, dynamic>.from(rows.first)),
    );
  }

  Stream<LiveLocation?> watchMechanicLocation(String bookingId) =>
      watchBookingLocation(bookingId);

  static Future<Position?> getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> updateMechanicLocation({
    required String bookingId,
    required String mechanicId,
    required Position position,
  }) async {
    final existing = await client
        .from('booking_locations')
        .select(
      'customer_id,customer_latitude,customer_longitude,customer_accuracy,customer_heading',
    )
        .eq('booking_id', bookingId)
        .maybeSingle();

    await client.from('booking_locations').upsert({
      'booking_id': bookingId,
      'mechanic_id': mechanicId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'heading': position.heading.isFinite ? position.heading : 0,
      'speed': position.speed,
      'customer_id': existing?['customer_id'],
      'customer_latitude': existing?['customer_latitude'],
      'customer_longitude': existing?['customer_longitude'],
      'customer_accuracy': existing?['customer_accuracy'],
      'customer_heading': existing?['customer_heading'] ?? 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'booking_id');
  }

  Future<void> updateCustomerLocation({
    required String bookingId,
    required String customerId,
    required Position position,
  }) async {
    final existing = await client
        .from('booking_locations')
        .select('mechanic_id,latitude,longitude,accuracy,heading,speed')
        .eq('booking_id', bookingId)
        .maybeSingle();

    await client.from('booking_locations').upsert({
      'booking_id': bookingId,
      'mechanic_id': existing?['mechanic_id'],
      'latitude': existing?['latitude'],
      'longitude': existing?['longitude'],
      'accuracy': existing?['accuracy'],
      'heading': existing?['heading'] ?? 0,
      'speed': existing?['speed'],
      'customer_id': customerId,
      'customer_latitude': position.latitude,
      'customer_longitude': position.longitude,
      'customer_accuracy': position.accuracy,
      'customer_heading': position.heading.isFinite ? position.heading : 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'booking_id');
  }

  Future<void> clearMechanicLocation(String bookingId) async {
    final row = await client
        .from('booking_locations')
        .select(
      'customer_id,customer_latitude,customer_longitude,customer_accuracy,customer_heading',
    )
        .eq('booking_id', bookingId)
        .maybeSingle();
    if (row == null) return;
    if (row['customer_id'] != null) {
      await client
          .from('booking_locations')
          .update({
        'mechanic_id': null,
        'latitude': null,
        'longitude': null,
        'accuracy': null,
        'heading': 0,
        'speed': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
          .eq('booking_id', bookingId);
    } else {
      await client
          .from('booking_locations')
          .delete()
          .eq('booking_id', bookingId);
    }
  }
}
