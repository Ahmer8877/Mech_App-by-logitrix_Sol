import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/providers/mechanic_rating_provider.dart';
import '../../cores/providers/offers_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_atoms.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/radar_search_widget.dart';
import '../../widgets/step_progress.dart';
import 'tracking_screen.dart';

class OffersScreen extends ConsumerWidget {
  final String bookingId;

  const OffersScreen({super.key, required this.bookingId});

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    dynamic offer,
  ) async {
    final customerId = ref.read(authProvider).user?.id;
    if (customerId == null) return;

    try {
      await ref
          .read(offerRepositoryProvider)
          .acceptOffer(offer: offer, customerId: customerId);
      ref.invalidate(offersProvider(bookingId));

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TrackingScreen(bookingId: bookingId),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Failed to accept offer: $e')),
        );
      }
    }
  }

  Future<void> _cancelBooking(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(bookingRepositoryProvider).cancel(bookingId);
      ref.invalidate(bookingsProvider);
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Failed to cancel request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersProvider(bookingId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const FlowAppBar(title: 'Offers for you'),
      body: offers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: AppText('Failed to load offers: $error')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: RadarSearchWidget(
                title: 'Finding Nearby Mechanics',
                subtitle:
                    'Broadcasting request to mechanics within 8 km range...',
                onCancel: () => _cancelBooking(context, ref),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppText(
                        'Radar active · Searching for more mechanics within 8 km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppText(
                '${items.length} Offers Received',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
              const SizedBox(height: 10),
              ...items.map(
                (offer) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          offer.mechanicName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        _OfferRatingBadge(
                          mechanicId: offer.mechanicId,
                          fallbackRating: offer.mechanicRating,
                          estimatedTime: offer.estimatedTime,
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          'PKR ${offer.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if ((offer.message ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: AppText(
                              offer.message!,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        const SizedBox(height: 8),
                        AccentButton(
                          label: 'Select this offer',
                          onPressed: () => _accept(context, ref, offer),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OfferRatingBadge extends ConsumerWidget {
  final String mechanicId;
  final double fallbackRating;
  final String estimatedTime;

  const _OfferRatingBadge({
    required this.mechanicId,
    required this.fallbackRating,
    required this.estimatedTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ratingAsync = mechanicId.isNotEmpty
        ? ref.watch(mechanicRatingProvider(mechanicId))
        : null;

    final ratingVal = (ratingAsync?.valueOrNull != null && ratingAsync!.valueOrNull! > 0)
        ? ratingAsync.valueOrNull!
        : fallbackRating;

    final display = ratingVal > 0 ? ratingVal.toStringAsFixed(1) : '0.0';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 12, color: c.accent),
        const SizedBox(width: 3),
        Text(
          '$display · $estimatedTime',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: c.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
