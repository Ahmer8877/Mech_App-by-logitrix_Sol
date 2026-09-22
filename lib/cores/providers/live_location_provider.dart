import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../repositories/live_location_repository.dart';

final liveLocationRepositoryProvider = Provider<LiveLocationRepository>(
  (ref) => LiveLocationRepository(supabase),
);

final bookingLiveLocationProvider =
    StreamProvider.family<LiveLocation?, String>(
      (ref, bookingId) => ref
          .read(liveLocationRepositoryProvider)
          .watchBookingLocation(bookingId),
    );

final mechanicLiveLocationProvider =
    StreamProvider.family<LiveLocation?, String>(
      (ref, bookingId) => ref
          .read(liveLocationRepositoryProvider)
          .watchMechanicLocation(bookingId),
    );
