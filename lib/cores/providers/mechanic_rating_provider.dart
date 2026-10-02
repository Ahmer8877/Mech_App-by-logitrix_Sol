import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

/// The database trigger stores the authoritative mechanic rating in profiles.
/// The provider reads that value directly so the mobile app matches the admin
/// dashboard and refreshes whenever the mechanic profile changes.
final mechanicRatingProvider = StreamProvider.family<double, String>((
  ref,
  mechanicId,
) async* {
  Future<double> loadRating() async {
    try {
      final row = await supabase
          .from('profiles')
          .select('rating')
          .eq('id', mechanicId)
          .maybeSingle();
      final value = row?['rating'];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  yield await loadRating();

  // Realtime is the fast path; polling keeps the value fresh if a device or
  // network cannot keep a WebSocket subscription alive.
  final realtime = supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', mechanicId)
      .map<void>((_) {});
  final polling = Stream<void>.periodic(const Duration(seconds: 5));

  try {
    await for (final _ in realtime.mergeWith(polling)) {
      yield await loadRating();
    }
  } catch (_) {
    await for (final _ in polling) {
      yield await loadRating();
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
