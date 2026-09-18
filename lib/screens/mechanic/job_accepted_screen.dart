import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../widgets/app_buttons.dart';
import '../call/call_screen.dart';
import '../customer/chat_screen.dart';
import 'on_the_way_screen.dart';

class JobAcceptedScreen extends ConsumerWidget {
  final String bookingId;
  const JobAcceptedScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(bookingDetailsProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Offer Accepted')),
      body: SafeArea(
        child: a.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (b) {
            final customer = b?['customer'] as Map?;
            final name = customer?['full_name']?.toString() ?? 'Customer';
            final customerId = (customer?['id'] ?? b?['customer_id'])?.toString() ?? '';
            final initials = name
                .split(' ')
                .where((x) => x.isNotEmpty)
                .take(2)
                .map((x) => x[0])
                .join()
                .toUpperCase();

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  const Icon(Icons.check_circle, size: 56, color: Colors.green),
                  const SizedBox(height: 14),
                  const Text(
                    'Offer Accepted!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text('📍 ${b?['pickup_address'] ?? ''}'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlineActionButton(
                          label: 'Call Customer',
                          onPressed: customerId.isEmpty
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CallScreen(name: name, initials: initials),
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlineActionButton(
                          label: 'Chat',
                          onPressed: customerId.isEmpty
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        bookingId: bookingId,
                                        otherUserId: customerId,
                                        otherName: name,
                                      ),
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AccentButton(
                    label: 'Start Navigation',
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OnTheWayScreen(bookingId: bookingId),
                      ),
                    ),
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
