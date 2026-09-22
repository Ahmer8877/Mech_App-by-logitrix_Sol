import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cores/providers/bookings_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_atoms.dart';
import 'on_the_way_screen.dart';

class MechanicBookingsScreen extends ConsumerWidget {
  const MechanicBookingsScreen({super.key});

  Future<void> _cancelBooking(BuildContext context, WidgetRef ref, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this booking? The customer will be notified.'),
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
        ref.invalidate(mechanicBookingsProvider);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(mechanicBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(mechanicBookingsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final booking = items[index];
                final active =
                    booking.status == 'accepted' ||
                    booking.status == 'on_the_way' ||
                    booking.status == 'in_progress';
                return AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.service,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  booking.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.colors.textMuted,
                                  ),
                                ),
                                if (booking.address.isNotEmpty)
                                  Text(
                                    booking.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('PKR ${booking.price.toStringAsFixed(0)}'),
                            ],
                          ),
                        ],
                      ),
                      if (active) ...[
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OnTheWayScreen(bookingId: booking.id),
                                ),
                              ),
                              icon: const Icon(Icons.map_outlined, size: 14),
                              label: const Text('Open Map', style: TextStyle(fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _cancelBooking(context, ref, booking.id),
                              icon: Icon(Icons.cancel_outlined, size: 14, color: context.colors.danger),
                              label: Text('Cancel', style: TextStyle(fontSize: 11, color: context.colors.danger)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
