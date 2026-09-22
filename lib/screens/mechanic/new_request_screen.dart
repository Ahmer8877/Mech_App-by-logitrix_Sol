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
