import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../cores/models/booking_model.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/providers/mechanic_rating_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/step_progress.dart';
import 'payment_method_screen.dart';
import 'tracking_screen.dart';
import 'dart:ui' as ui;

class BookingHistoryScreen extends ConsumerStatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  ConsumerState<BookingHistoryScreen> createState() =>
      _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends ConsumerState<BookingHistoryScreen> {
  bool _upcoming = true;

  Future<void> _cancelBooking(BuildContext context, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText(
          'Cancel Booking?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const AppText('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const AppText('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(bookingRepositoryProvider).cancel(bookingId);
        ref.invalidate(bookingsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('Booking cancelled successfully.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: AppText('Failed to cancel booking: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final bookingsAsync = ref.watch(bookingsProvider);
    final allBookings = bookingsAsync.valueOrNull ?? const [];

    final list = allBookings.where((b) {
      final isFinished =
          b.completed || b.status == 'completed' || b.status == 'cancelled';
      return _upcoming ? !isFinished : isFinished;
    }).toList();

    return Scaffold(
      appBar: const FlowAppBar(title: 'Booking History'),
      body: bookingsAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookingsAsync.hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppText('Failed to load bookings.'),
                  TextButton(
                    onPressed: () => ref.invalidate(bookingsProvider),
                    child: const AppText('Retry'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Chip(
                        label: 'Upcoming',
                        selected: _upcoming,
                        onTap: () => setState(() => _upcoming = true),
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: 'Completed',
                        selected: !_upcoming,
                        onTap: () => setState(() => _upcoming = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: AppText(
                              'No bookings found',
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final b = list[i];
                              final isFinished =
                                  b.completed ||
                                  b.status == 'completed' ||
                                  b.status == 'cancelled';

                              return InkWell(
                                onTap: isFinished
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TrackingScreen(bookingId: b.id),
                                          ),
                                        );
                                      },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: c.borderStrong.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              AppText(
                                                b.service,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              AppText(
                                                '${b.mechanic} · ${b.createdAt == null ? 'Recent' : DateFormat('dd MMM yyyy').format(b.createdAt!.toLocal())}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: c.textMuted,
                                                ),
                                              ),
                                              if (b.mechanic != 'Not assigned')
                                                _BookingRatingBadge(booking: b),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              AppText(
                                                'PKR ${b.price.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isFinished
                                                      ? (b.status == 'cancelled'
                                                            ? c.danger
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  )
                                                            : c.success
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  ))
                                                      : c.surface2,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: AppText(
                                                  b.status == 'cancelled'
                                                      ? 'Cancelled'
                                                      : (isFinished
                                                            ? 'Completed'
                                                            : b.status),
                                                  style: TextStyle(
                                                    fontSize: 8.5,
                                                    color:
                                                        b.status == 'cancelled'
                                                        ? c.danger
                                                        : (isFinished
                                                              ? c.success
                                                              : scheme.primary),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (!isFinished) ...[
                                        const Divider(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: TextButton.icon(
                                                onPressed: () =>
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            TrackingScreen(
                                                              bookingId: b.id,
                                                            ),
                                                      ),
                                                    ),
                                                icon: Icon(
                                                  Icons.map_outlined,
                                                  size: 13,
                                                  color: scheme.primary,
                                                ),
                                                label: AppText(
                                                  'Map',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: scheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                      ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () =>
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          PaymentMethodScreen(
                                                            bookingId: b.id,
                                                          ),
                                                    ),
                                                  ),
                                              icon: const Icon(
                                                Icons.payment,
                                                size: 13,
                                              ),
                                              label: const AppText(
                                                'Pay',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _cancelBooking(context, b.id),
                                              icon: Icon(
                                                Icons.cancel_outlined,
                                                size: 13,
                                                color: c.danger,
                                              ),
                                              label: AppText(
                                                'Cancel',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: c.danger,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : c.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AppText(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? scheme.onPrimary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _BookingRatingBadge extends ConsumerWidget {
  final Booking booking;
  const _BookingRatingBadge({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    
    // 1. If this specific booking has a review rating given by customer, show that exact rating
    double? ratingVal = booking.userRating;

    // 2. Otherwise watch the live average rating of the mechanic (e.g. 4.5)
    if (ratingVal == null || ratingVal <= 0) {
      final ratingAsync = booking.mechanicId.isNotEmpty
          ? ref.watch(mechanicRatingProvider(booking.mechanicId))
          : null;
      ratingVal = (ratingAsync?.valueOrNull != null && ratingAsync!.valueOrNull! > 0)
          ? ratingAsync.valueOrNull!
          : booking.mechanicRating;
    }

    if (ratingVal <= 0) {
      return AppText(
        'Not rated yet',
        style: TextStyle(
          fontSize: 10,
          color: c.textMuted,
        ),
      );
    }

    final display = ratingVal.toStringAsFixed(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 12, color: c.accent),
        const SizedBox(width: 3),
        Text(
          display,
          textDirection: ui.TextDirection.ltr,
          style: TextStyle(
            fontSize: 10.5,
            color: c.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
