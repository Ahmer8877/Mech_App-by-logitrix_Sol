import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/offer_model.dart';

class OfferRepository {
  final SupabaseClient client;
  OfferRepository(this.client);
  Future<List<Offer>> getOffers(String bookingId) async {
    final rows = await client
        .from('offers')
        .select(
          '*, mechanic:profiles!offers_mechanic_id_fkey(full_name,rating)',
        )
        .eq('booking_id', bookingId)
        .order('created_at');
    return (rows as List)
        .map((e) => Offer.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> sendOffer({
    required String bookingId,
    required String mechanicId,
    required double price,
    required String estimatedTime,
    String? message,
  }) async {
    await client.from('offers').upsert({
      'booking_id': bookingId,
      'mechanic_id': mechanicId,
      'price': price,
      'estimated_time': estimatedTime,
      'message': message,
      'status': 'pending',
    }, onConflict: 'booking_id,mechanic_id');
  }

  Future<void> acceptOffer({
    required Offer offer,
    required String customerId,
  }) async {
    await client.rpc(
      'accept_offer',
      params: {'p_offer_id': offer.id, 'p_customer_id': customerId},
    );
  }
}
