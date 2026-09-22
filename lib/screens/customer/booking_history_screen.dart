import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/step_progress.dart';
import 'payment_method_screen.dart';

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
        title: const Text('Cancel Booking?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
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
            const SnackBar(content: Text('Booking cancelled successfully.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel booking: $e')),
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
      final isFinished = b.completed || b.status == 'completed' || b.status == 'cancelled';
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
                  const Text('Failed to load bookings.'),
                  TextButton(
                    onPressed: () => ref.invalidate(bookingsProvider),
                    child: const Text('Retry'),
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
                            child: Text(
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
                              final isFinished = b.completed || b.status == 'completed' || b.status == 'cancelled';

                              return Container(
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
                                            Text(
                                              b.service,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${b.mechanic} · ${b.createdAt == null ? 'Recent' : DateFormat('dd MMM yyyy').format(b.createdAt!.toLocal())}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: c.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'PKR ${b.price.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isFinished
                                                    ? (b.status == 'cancelled'
                                                        ? c.danger.withValues(alpha: 0.15)
                                                        : c.success.withValues(alpha: 0.15))
                                                    : c.surface2,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                b.status == 'cancelled'
                                                    ? 'Cancelled'
                                                    : (isFinished ? 'Completed' : b.status),
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  color: b.status == 'cancelled'
                                                      ? c.danger
                                                      : (isFinished ? c.success : scheme.primary),
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
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => PaymentMethodScreen(bookingId: b.id),
                                              ),
                                            ),
                                            icon: const Icon(Icons.payment, size: 14),
                                            label: const Text('Pay & Complete', style: TextStyle(fontSize: 11)),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            onPressed: () => _cancelBooking(context, b.id),
                                            icon: Icon(Icons.cancel_outlined, size: 14, color: c.danger),
                                            label: Text('Cancel', style: TextStyle(fontSize: 11, color: c.danger)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
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
        child: Text(
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
