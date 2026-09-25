import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/providers/offers_provider.dart';
import '../../cores/repositories/live_location_repository.dart';
import '../../widgets/app_buttons.dart';

class SendOfferScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const SendOfferScreen({super.key, required this.bookingId});
  @override
  ConsumerState<SendOfferScreen> createState() => _SendOfferScreenState();
}

class _SendOfferScreenState extends ConsumerState<SendOfferScreen> {
  final price = TextEditingController(),
      time = TextEditingController(text: '30 min'),
      message = TextEditingController();
  bool saving = false;
  @override
  void dispose() {
    price.dispose();
    time.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final uid = ref.read(authProvider).user?.id;
    final p = double.tryParse(price.text.trim());
    if (uid == null || p == null || p <= 0) return;
    setState(() => saving = true);
    try {
      final rawBooking = await ref
          .read(bookingRepositoryProvider)
          .getRawBooking(widget.bookingId);
      final reqLat = (rawBooking?['latitude'] as num?)?.toDouble();
      final reqLng = (rawBooking?['longitude'] as num?)?.toDouble();

      if (reqLat != null && reqLng != null) {
        final pos = await LiveLocationRepository.getCurrentPosition();
        if (pos != null) {
          final distMeters = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            reqLat,
            reqLng,
          );
          if (distMeters > 5000.0) {
            final distKm = (distMeters / 1000.0).toStringAsFixed(1);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Aap customer se $distKm km door hain. Offer sirf 5 km range ke andar bhej sakte hain.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      }

      await ref
          .read(offerRepositoryProvider)
          .sendOffer(
            bookingId: widget.bookingId,
            mechanicId: uid,
            price: p,
            estimatedTime: time.text.trim(),
            message: message.text.trim(),
          );
      ref.invalidate(openRequestsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(bookingDetailsProvider(widget.bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Send Your Offer')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            b.when(
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
              data: (x) => Text(
                'Customer budget: PKR ${((x?['budget_price'] as num?) ?? 0).toStringAsFixed(0)}',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Your offer price',
                prefixText: 'PKR ',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: time,
              decoration: const InputDecoration(labelText: 'Estimated time'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: message,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
              ),
            ),
            const Spacer(),
            AccentButton(
              label: saving ? 'Sending...' : 'Send Offer',
              onPressed: saving ? null : send,
            ),
          ],
        ),
      ),
    );
  }
}
