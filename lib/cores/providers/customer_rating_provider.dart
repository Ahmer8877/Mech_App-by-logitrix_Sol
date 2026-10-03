import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import 'auth_provider.dart';

/// StreamProvider dynamically calculating customer's 'Given Rating' average in real-time.
/// Listens to real-time changes in Supabase 'reviews' table for the logged-in customer ID.
final customerRatingProvider = StreamProvider.autoDispose<double?>((
  ref,
) async* {
  final userId =
      ref.watch(authProvider.select((state) => state.user?.id)) ??
      supabase.auth.currentUser?.id;

  if (userId == null) {
    yield null;
    return;
  }

  Future<double?> loadAvg() async {
    try {
      final rows = await supabase
          .from('reviews')
          .select('rating')
          .eq('customer_id', userId);

      if (rows.isEmpty) return null;

      final ratings = rows
          .map((row) => (row['rating'] as num?)?.toDouble())
          .whereType<double>()
          .toList();

      if (ratings.isEmpty) return null;
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      final parsed = double.parse(avg.toStringAsFixed(1));
      debugPrint('customerRatingProvider for $userId: avg = $parsed');
      return parsed;
    } catch (e) {
      debugPrint('customerRatingProvider loadAvg error for $userId: $e');
      return null;
    }
  }

  yield await loadAvg();

  final realtime = supabase
      .from('reviews')
      .stream(primaryKey: ['id'])
      .eq('customer_id', userId)
      .handleError((e) => debugPrint('customerRating realtime error: $e'))
      .map<void>((_) {});
  final polling = Stream<void>.periodic(const Duration(seconds: 4));

  final safeStream = realtime.mergeWith(polling).handleError((e) => debugPrint('customerRating safeStream error: $e'));

  await for (final _ in safeStream) {
    try {
      yield await loadAvg();
    } catch (e) {
      debugPrint('customerRatingProvider iteration error: $e');
    }
  }
});

extension _CustomerRatingStreamMerge<T> on Stream<T> {
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

    first = listen(controller.add, onError: (e) => debugPrint('customer first stream error: $e'), onDone: close);
    second = other.listen(
      controller.add,
      onError: (e) => debugPrint('customer second stream error: $e'),
      onDone: close,
    );
    controller.onCancel = () async {
      await first.cancel();
      await second.cancel();
    };
    return controller.stream;
  }
}
