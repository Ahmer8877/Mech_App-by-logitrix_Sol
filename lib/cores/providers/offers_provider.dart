import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/offer_model.dart';
import '../repositories/offer_repository.dart';

final offerRepositoryProvider = Provider((ref) => OfferRepository(supabase));

final offersProvider = StreamProvider.family<List<Offer>, String>((
  ref,
  bookingId,
) async* {
  final repo = ref.read(offerRepositoryProvider);
  yield await repo.getOffers(bookingId);

  try {
    yield* supabase
        .from('offers')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .order('created_at')
        .handleError((e) => debugPrint('Offers stream error: $e'))
        .asyncMap((_) => repo.getOffers(bookingId));
  } catch (e) {
    debugPrint('Offers catch: $e');
  }
});
