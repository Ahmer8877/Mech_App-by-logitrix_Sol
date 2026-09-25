import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_atoms.dart';
import '../../widgets/app_buttons.dart';
import 'send_offer_screen.dart';
import 'request_details_screen.dart';

class NewRequestScreen extends ConsumerWidget {
  const NewRequestScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(mechanicOnlineStatusProvider);

    if (!isOnline) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Requests')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 40,
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                const Text(
                  'You are currently offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Turn on your online status from Home to view and accept new service requests.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final requests = ref.watch(openRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New Requests')),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load requests: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No new requests right now.'))
            : ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final b = items[i];
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['service_title']?.toString() ?? 'Service',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b['pickup_address']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        if (b['distance_km'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.near_me,
                                size: 11,
                                color: b['is_within_range'] == false
                                    ? Colors.orange
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                b['is_within_range'] == false
                                    ? '${b['distance_km']} km away (Out of 5 km range)'
                                    : '${b['distance_km']} km away (Within 5 km range)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: b['is_within_range'] == false
                                      ? Colors.orange
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          'CUSTOMER BUDGET',
                          style: TextStyle(
                            fontSize: 9,
                            color: context.colors.textMuted,
                          ),
                        ),
                        Text(
                          'PKR ${((b['budget_price'] as num?) ?? 0).toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlineActionButton(
                                label: 'View Details',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RequestDetailsScreen(
                                      bookingId: b['id'].toString(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AccentButton(
                                label: 'Send Offer',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SendOfferScreen(
                                      bookingId: b['id'].toString(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
