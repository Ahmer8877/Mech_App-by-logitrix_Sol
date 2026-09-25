import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/bookings_provider.dart';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept offer: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cancel request: $e')));
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
            Center(child: Text('Failed to load offers: $error')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: RadarSearchWidget(
                title: 'Finding Nearby Mechanics',
                subtitle:
                    'Broadcasting request to mechanics within 5 km range...',
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
                      child: Text(
                        'Radar active · Searching for more mechanics within 5 km',
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
              Text(
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
                        Text(
                          offer.mechanicName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '⭐ ${offer.mechanicRating.toStringAsFixed(1)} · ${offer.estimatedTime}',
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'PKR ${offer.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if ((offer.message ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
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
