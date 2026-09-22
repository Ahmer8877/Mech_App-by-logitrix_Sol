import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import 'auth_provider.dart';

/// StreamProvider dynamically calculating customer's 'Given Rating' average in real-time.
/// Listens to real-time changes in Supabase 'reviews' table for the logged-in customer ID.
/// Updates ProfileScreen immediately when a new review is submitted without needing app restart.
final customerRatingProvider = StreamProvider.autoDispose<double?>((ref) async* {
  final userId = ref.watch(authProvider.select((state) => state.user?.id)) ??
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
      return ratings.reduce((a, b) => a + b) / ratings.length;
    } catch (_) {
      return null;
    }
  }

  yield await loadAvg();

  try {
    await for (final _ in supabase
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)) {
      yield await loadAvg();
    }
  } catch (_) {}
});
