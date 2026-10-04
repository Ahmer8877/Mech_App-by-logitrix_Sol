import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/step_progress.dart';
import 'rate_mechanic_screen.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const PaymentMethodScreen({super.key, required this.bookingId});

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  bool _saving = false;

  Future<void> _pay() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .markPaid(widget.bookingId, 'Cash');
      ref.invalidate(bookingsProvider);
      ref.invalidate(bookingDetailsProvider(widget.bookingId));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RateMechanicScreen(bookingId: widget.bookingId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('Payment update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingDetailsProvider(widget.bookingId));

    return Scaffold(
      appBar: const FlowAppBar(title: 'Payment Method'),
      body: booking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: AppText('$error')),
        data: (data) {
          if (data == null) {
            return const Center(child: AppText('Booking not found.'));
          }

          final rawAmount = data['agreed_price'] ?? data['budget_price'];
          final amount = rawAmount is num ? rawAmount.toDouble() : 0.0;

          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.payments_outlined),
                      SizedBox(width: 10),
                      AppText('Cash'),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppText('Total Amount'),
                    AppText('PKR ${amount.toStringAsFixed(0)}'),
                  ],
                ),
                const SizedBox(height: 10),
                AccentButton(
                  label: _saving ? 'Saving...' : 'Confirm Payment & Rate',
                  onPressed: _saving ? null : _pay,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
