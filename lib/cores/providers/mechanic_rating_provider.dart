import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

/// StreamProvider providing the mechanic's authoritative average rating in real-time.
/// Directly calculates average from the 'reviews' table and falls back to 'profiles.rating'.
/// Listens to real-time changes on both 'reviews' and 'profiles' tables to update instantly.
final mechanicRatingProvider = StreamProvider.family<double, String>((
  ref,
  mechanicId,
) async* {
  if (mechanicId.isEmpty) {
    yield 0.0;
    return;
  }

  Future<double> loadRating() async {
    try {
      // 1. Calculate direct average from reviews table (Public read policy allows this)
      final reviewsRes = await supabase
          .from('reviews')
          .select('rating')
          .eq('mechanic_id', mechanicId);

      if (reviewsRes.isNotEmpty) {
        final ratings = reviewsRes
            .map((r) => (r['rating'] as num?)?.toDouble())
            .whereType<double>()
            .toList();
        if (ratings.isNotEmpty) {
          final avg = ratings.reduce((a, b) => a + b) / ratings.length;
          final parsed = double.parse(avg.toStringAsFixed(1));
          debugPrint(
            'mechanicRatingProvider for $mechanicId: calculated from reviews = $parsed',
          );
          return parsed;
        }
      }

      // 2. Fallback to profiles.rating
      final row = await supabase
          .from('profiles')
          .select('rating')
          .eq('id', mechanicId)
          .maybeSingle();
      final value = row?['rating'];
      final fallback = value is num
          ? value.toDouble()
          : (double.tryParse(value?.toString() ?? '') ?? 0.0);
      debugPrint(
        'mechanicRatingProvider for $mechanicId: fallback from profiles = $fallback',
      );
      return fallback;
    } catch (e) {
      debugPrint('mechanicRatingProvider loadRating error for $mechanicId: $e');
      return 0.0;
    }
  }

  // Yield initial value immediately
  yield await loadRating();

  // Safely subscribe to realtime streams with error handling so WebSocket drops
  // do NOT wipe the calculated rating out or set Riverpod into AsyncError.
  final reviewsStream = supabase
      .from('reviews')
      .stream(primaryKey: ['id'])
      .eq('mechanic_id', mechanicId)
      .handleError((e) => debugPrint('mechanicRating reviewsStream error: $e'))
      .map<void>((_) {});

  final profilesStream = supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', mechanicId)
      .handleError((e) => debugPrint('mechanicRating profilesStream error: $e'))
      .map<void>((_) {});

  final polling = Stream<void>.periodic(const Duration(seconds: 4));

  final safeStream = reviewsStream
      .mergeWith(profilesStream)
      .mergeWith(polling)
      .handleError((e) => debugPrint('mechanicRating safeStream error: $e'));

  await for (final _ in safeStream) {
    try {
      yield await loadRating();
    } catch (e) {
      debugPrint('mechanicRatingProvider iteration error: $e');
    }
  }
});

extension _RatingStreamMerge<T> on Stream<T> {
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

    first = listen(
      controller.add,
      onError: (e) => debugPrint('first stream error: $e'),
      onDone: close,
    );
    second = other.listen(
      controller.add,
      onError: (e) => debugPrint('second stream error: $e'),
      onDone: close,
    );
    controller.onCancel = () async {
      await first.cancel();
      await second.cancel();
    };
    return controller.stream;
  }
}
