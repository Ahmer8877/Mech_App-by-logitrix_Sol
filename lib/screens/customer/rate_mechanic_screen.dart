import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/config/supabase_config.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/providers/mechanic_stats_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import 'customer_home_screen.dart';

class RateMechanicScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const RateMechanicScreen({super.key, required this.bookingId});
  @override
  ConsumerState<RateMechanicScreen> createState() => _RateMechanicScreenState();
}

class _RateMechanicScreenState extends ConsumerState<RateMechanicScreen> {
  int rating = 5;
  final comment = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> submit(Map<String, dynamic>? b) async {
    final uid = ref.read(authProvider).user?.id;
    final mid =
        (b?['mechanic'] as Map?)?['id']?.toString() ??
        b?['mechanic_id']?.toString();
    if (uid == null || mid == null) return;
    setState(() => saving = true);
    try {
      // 1. Submit review
      await supabase.from('reviews').upsert({
        'booking_id': widget.bookingId,
        'customer_id': uid,
        'mechanic_id': mid,
        'rating': rating,
        'comment': comment.text.trim(),
      }, onConflict: 'booking_id,customer_id');

      // 2. Calculate dynamic average rating and update mechanic's profile in Supabase
      final reviewsResponse = await supabase
          .from('reviews')
          .select('rating')
          .eq('mechanic_id', mid);

      if (reviewsResponse.isNotEmpty) {
        final totalReviews = reviewsResponse.length;
        final sumRating = reviewsResponse.fold<double>(
          0.0,
          (sum, item) => sum + ((item['rating'] as num?)?.toDouble() ?? 5.0),
        );
        final avgRating = double.parse(
          (sumRating / totalReviews).toStringAsFixed(1),
        );

        await supabase
            .from('profiles')
            .update({'rating': avgRating, 'total_jobs': totalReviews})
            .eq('id', mid);
      }

      // 3. Mark booking as COMPLETED and PAID
      await ref.read(bookingRepositoryProvider).complete(widget.bookingId);

      ref.invalidate(bookingsProvider);
      ref.invalidate(bookingDetailsProvider(widget.bookingId));
      ref.invalidate(mechanicStatsProvider);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(bookingDetailsProvider(widget.bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Your Experience')),
      body: b.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => (Center(child: Text('$e'))),
        data: (x) => Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(
                (x?['mechanic'] as Map?)?['full_name']?.toString() ??
                    'Mechanic',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: () => setState(() => rating = i + 1),
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: context.colors.accent,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Write your review (optional)',
                ),
              ),
              const Spacer(),
              AccentButton(
                label: saving
                    ? 'Submitting & Completing...'
                    : 'Submit Review & Complete',
                onPressed: saving ? null : () => submit(x),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
