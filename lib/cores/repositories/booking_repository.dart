import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final SupabaseClient client;
  BookingRepository(this.client);

  Future<List<Booking>> getCustomerBookings(String userId) async {
    final rows = await client
        .from('bookings')
        .select(
          '*, mechanic:profiles!bookings_mechanic_id_fkey(id,full_name,rating,phone_number), service:services(title)',
        )
        .eq('customer_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Booking.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Booking>> getMechanicBookings(String userId) async {
    final rows = await client
        .from('bookings')
        .select(
          '*, customer:profiles!bookings_customer_id_fkey(id,full_name,phone_number), service:services(title), vehicle:vehicles(make_model,license_plate,year)',
        )
        .eq('mechanic_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Booking.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getOpenRequests() async {
    final rows = await client
        .from('bookings')
        .select(
          '*, customer:profiles!bookings_customer_id_fkey(id,full_name,phone_number), service:services(title), vehicle:vehicles(make_model,license_plate,year)',
        )
        .isFilter('mechanic_id', null)
        .or('status.eq.pending,status.eq.offered')
        .order('created_at', ascending: false);
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> getRawBooking(String id) async => await client
      .from('bookings')
      .select(
        '*, customer:profiles!bookings_customer_id_fkey(id,full_name,phone_number), mechanic:profiles!bookings_mechanic_id_fkey(id,full_name,rating,phone_number), service:services(title), vehicle:vehicles(make_model,license_plate,year)',
      )
      .eq('id', id)
      .maybeSingle();

  Future<String> createBooking({
    required String customerId,
    required String vehicleId,
    required String serviceId,
    required String serviceTitle,
    required String description,
    required List<String> photoUrls,
    required String address,
    double? latitude,
    double? longitude,
    double? budget,
    String? paymentMethod,
  }) async {
    final res = await client
        .from('bookings')
        .insert({
          'customer_id': customerId,
          'vehicle_id': vehicleId,
          'service_id': serviceId,
          'service_title': serviceTitle,
          'description': description,
          'photo_urls': photoUrls,
          'pickup_address': address,
          'latitude': ?latitude,
          'longitude': ?longitude,
          'status': 'pending',
          'budget_price': budget ?? 0,
          'payment_method': paymentMethod ?? 'Cash',
        })
        .select('id')
        .single();
    return res['id'].toString();
  }

  Future<void> setPaymentMethod(String bookingId, String method) async {
    await client.from('bookings').update({
      'payment_method': method,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', bookingId);
  }

  Future<void> markPaid(String bookingId, String method) async {
    await client.from('bookings').update({
      'is_paid': true,
      'payment_method': method,
      'status': 'completed',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', bookingId);
  }

  Future<void> updateStatus(String bookingId, String status) async {
    await client.from('bookings').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', bookingId);
  }

  Future<void> complete(String bookingId) async {
    await client.from('bookings').update({
      'status': 'completed',
      'is_paid': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', bookingId);
  }

  Future<void> cancel(String bookingId) async {
    await client.from('bookings').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', bookingId);
  }
}
