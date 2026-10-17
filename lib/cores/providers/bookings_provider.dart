import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../config/supabase_config.dart';
import '../models/booking_model.dart';
import '../repositories/booking_repository.dart';
import '../repositories/live_location_repository.dart';
import '../config/service_radius.dart';
import 'auth_provider.dart';

final bookingRepositoryProvider = Provider(
  (ref) => BookingRepository(supabase),
);

/// Set of booking IDs that the active mechanic has ignored/dismissed.
final ignoredRequestsProvider = StateProvider<Set<String>>((ref) => {});

/// Tracks whether the active mechanic is online and accepting requests.
final mechanicOnlineStatusProvider = StateProvider<bool>((ref) => true);

final bookingsProvider = StreamProvider<List<Booking>>((ref) async* {
  final id = ref.watch(authProvider.select((s) => s.user?.id));
  if (id == null) {
    yield const [];
    return;
  }

  final repo = ref.read(bookingRepositoryProvider);
  yield await repo.getCustomerBookings(id);

  try {
    final bookingsStream = supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('customer_id', id)
        .map<void>((_) {});

    final reviewsStream = supabase
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('customer_id', id)
        .map<void>((_) {});

    final polling = Stream<void>.periodic(const Duration(seconds: 5));

    await for (final _
        in bookingsStream.mergeWith(reviewsStream).mergeWith(polling)) {
      yield await repo.getCustomerBookings(id);
    }
  } catch (e) {
    debugPrint('Customer bookings stream catch: $e');
  }
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
    final bookingsStream = supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('mechanic_id', id)
        .map<void>((_) {});

    final reviewsStream = supabase
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('mechanic_id', id)
        .map<void>((_) {});

    final polling = Stream<void>.periodic(const Duration(seconds: 5));

    await for (final _
        in bookingsStream.mergeWith(reviewsStream).mergeWith(polling)) {
      yield await repo.getMechanicBookings(id);
    }
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
      maxDistanceMeters: mechanicServiceRadiusMeters,
    );
    if (ignoredSet.isEmpty) return list;
    return list
        .where((item) => !ignoredSet.contains(item['id']?.toString()))
        .toList();
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
        final bookingStream = supabase
            .from('bookings')
            .stream(primaryKey: ['id'])
            .eq('id', id)
            .map<void>((_) {});

        final reviewsStream = supabase
            .from('reviews')
            .stream(primaryKey: ['id'])
            .eq('booking_id', id)
            .map<void>((_) {});

        final polling = Stream<void>.periodic(const Duration(seconds: 4));

        await for (final _
            in bookingStream.mergeWith(reviewsStream).mergeWith(polling)) {
          yield await repo.getRawBooking(id);
        }
      } catch (e) {
        debugPrint('Booking details catch: $e');
      }
    });

extension _BookingsStreamMerge<T> on Stream<T> {
  Stream<T> mergeWith(Stream<T> other) {
    final controller = StreamController<T>();
    late StreamSubscription<T> first;
    late StreamSubscription<T> second;
    var closed = false;

    void close() {
      if (closed) return;
      closed = true;
      controller.close();
    }

    first = listen(controller.add, onError: controller.addError, onDone: close);
    second = other.listen(
      controller.add,
      onError: controller.addError,
      onDone: close,
    );
    controller.onCancel = () async {
      await first.cancel();
      await second.cancel();
    };
    return controller.stream;
  }
}
