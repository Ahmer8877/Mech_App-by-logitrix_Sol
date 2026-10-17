import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class holding real-time GPS coordinates for active mechanic and customer.
/// Contains latitude, longitude, and heading values for both booking participants.
/// Used by LiveGoogleMap to draw real-time animated markers and navigation routes.
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

/// Repository managing live GPS location updates and streams via Supabase.
/// Connects to 'booking_locations' table to upsert and watch real-time coordinates.
/// Used by OnTheWayScreen (Mechanic) and TrackingScreen (Customer) during active jobs.
class LiveLocationRepository {
  final SupabaseClient client;
  LiveLocationRepository(this.client);

  /// Subscribes to real-time location stream for a specific active booking.
  /// Listens to PostgreSQL changes in 'booking_locations' table matching bookingId.
  /// Yields updated LiveLocation models whenever mechanic or customer coordinates move.
  Stream<LiveLocation?> watchBookingLocation(String bookingId) {
    return client
        .from('booking_locations')
        .stream(primaryKey: ['booking_id'])
        .eq('booking_id', bookingId)
        .handleError((e) {
          debugPrint('Live location stream error: $e');
        })
        .map(
          (rows) => rows.isEmpty
              ? null
              : LiveLocation.fromMap(Map<String, dynamic>.from(rows.first)),
        );
  }

  Stream<LiveLocation?> watchMechanicLocation(String bookingId) =>
      watchBookingLocation(bookingId);

  /// Acquires current high-accuracy device GPS position using Geolocator package.
  /// Checks and requests location permissions if not yet granted by user.
  /// Returns Position object or null if location services/permissions are disabled.
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

  /// Upserts mechanic's current GPS position into 'booking_locations' table.
  /// Preserves existing customer coordinates while updating mechanic latitude and heading.
  /// Triggers real-time location stream updates on the customer's tracking map screen.
  Future<void> updateMechanicLocation({
    required String bookingId,
    required String mechanicId,
    required Position position,
  }) async {
    try {
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
    } catch (e) {
      debugPrint('Error updating mechanic location: $e');
    }
  }

  /// Upserts customer's current GPS position into 'booking_locations' table.
  /// Preserves existing mechanic coordinates while updating customer latitude and heading.
  /// Enables mechanic to see customer's precise live location on their navigation map.
  Future<void> updateCustomerLocation({
    required String bookingId,
    required String customerId,
    required Position position,
  }) async {
    try {
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
    } catch (e) {
      debugPrint('Error updating customer location: $e');
    }
  }

  /// Clears mechanic location from 'booking_locations' table upon job completion.
  /// Resets mechanic coordinates to null or deletes the row if customer is also done.
  /// Stops active GPS stream tracking when booking transitions to completed status.
  Future<void> clearMechanicLocation(String bookingId) async {
    try {
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
    } catch (_) {}
  }
}
