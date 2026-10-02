import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../widgets/app_atoms.dart';
import '../../widgets/app_buttons.dart';
import 'rate_mechanic_screen.dart';

class PaymentRatingScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const PaymentRatingScreen({super.key, required this.bookingId});

  @override
  ConsumerState<PaymentRatingScreen> createState() =>
      _PaymentRatingScreenState();
}

class _PaymentRatingScreenState extends ConsumerState<PaymentRatingScreen> {
  String _method = 'Cash';
  bool _saving = false;

  Future<void> _pay() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .markPaid(widget.bookingId, _method);
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
      body: SafeArea(
        child: booking.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: AppText('$error')),
          data: (data) {
            if (data == null) {
              return const Center(child: AppText('Booking not found.'));
            }

            final rawAmount = data['agreed_price'] ?? data['budget_price'];
            final amount = rawAmount is num ? rawAmount.toDouble() : 0.0;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.check_circle, size: 60),
                  const SizedBox(height: 12),
                  const AppText('Job Completed!'),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const AppText('Total'),
                        AppText('PKR ${amount.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    items:
                        const [
                          'Cash',
                          'Credit / Debit Card',
                          'JazzCash / Easypaisa',
                        ].map((method) {
                          return DropdownMenuItem(
                            value: method,
                            child: AppText(method),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _method = value);
                    },
                  ),
                  const Spacer(),
                  AccentButton(
                    label: _saving ? 'Saving...' : 'Confirm Payment',
                    onPressed: _saving ? null : _pay,
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
