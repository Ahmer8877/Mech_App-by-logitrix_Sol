import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../config/supabase_config.dart';
import '../models/booking_model.dart';
import '../repositories/booking_repository.dart';
import '../repositories/live_location_repository.dart';
import 'auth_provider.dart';

final bookingRepositoryProvider = Provider(
  (ref) => BookingRepository(supabase),
);

/// Set of booking IDs that the active mechanic has ignored/dismissed.
final ignoredRequestsProvider = StateProvider<Set<String>>((ref) => {});

/// Tracks whether the active mechanic is online and accepting requests.
final mechanicOnlineStatusProvider = StateProvider<bool>((ref) => true);

final bookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final id = ref.watch(authProvider.select((s) => s.user?.id));
  if (id == null) return const [];
  return ref.read(bookingRepositoryProvider).getCustomerBookings(id);
});

final mechanicBookingsProvider = StreamProvider<List<Booking>>((ref) async* {
  final id = ref.watch(authProvider.select((s) => s.user?.id));
  if (id == null) {
    yield const [];
    return;
  }

  final repo = ref.read(bookingRepositoryProvider);
  yield await repo.getMechanicBookings(id);

  try {
    yield* supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .handleError((e) => debugPrint('Mechanic bookings stream error: $e'))
        .asyncMap((_) => repo.getMechanicBookings(id));
  } catch (e) {
    debugPrint('Mechanic bookings catch: $e');
  }
});

final openRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) async* {
  final isOnline = ref.watch(mechanicOnlineStatusProvider);
  if (!isOnline) {
    yield const [];
    return;
  }

  final repo = ref.read(bookingRepositoryProvider);
  final ignoredSet = ref.watch(ignoredRequestsProvider);

  Position? pos;
  try {
    pos = await LiveLocationRepository.getCurrentPosition();
  } catch (_) {}

  Future<List<Map<String, dynamic>>> fetch() async {
    final currentOnline = ref.read(mechanicOnlineStatusProvider);
    if (!currentOnline) return const [];

    final list = await repo.getOpenRequests(
      mechanicLat: pos?.latitude,
      mechanicLng: pos?.longitude,
      maxDistanceMeters: 5000.0,
    );
    if (ignoredSet.isEmpty) return list;
    return list.where((item) => !ignoredSet.contains(item['id']?.toString())).toList();
  }

  yield await fetch();

  try {
    await for (final _
        in supabase
            .from('bookings')
            .stream(primaryKey: ['id'])
            .handleError((e) => debugPrint('Open requests stream error: $e'))) {
      if (!ref.read(mechanicOnlineStatusProvider)) {
        yield const [];
        continue;
      }
      yield await fetch();
    }
  } catch (e) {
    debugPrint('Open requests catch: $e');
  }
});

final bookingDetailsProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, id) async* {
      final repo = ref.read(bookingRepositoryProvider);
      yield await repo.getRawBooking(id);

      try {
        yield* supabase
            .from('bookings')
            .stream(primaryKey: ['id'])
            .eq('id', id)
            .handleError((e) => debugPrint('Booking details stream error: $e'))
            .asyncMap((_) => repo.getRawBooking(id));
      } catch (e) {
        debugPrint('Booking details catch: $e');
      }
    });
