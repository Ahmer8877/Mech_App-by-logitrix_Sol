import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/repositories/live_location_repository.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_atoms.dart';
import '../../widgets/app_buttons.dart';
import 'send_offer_screen.dart';

class RequestDetailsScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const RequestDetailsScreen({super.key, required this.bookingId});

  @override
  ConsumerState<RequestDetailsScreen> createState() =>
      _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends ConsumerState<RequestDetailsScreen> {
  double? _distanceMeters;
  bool _calculatingDistance = true;

  @override
  void initState() {
    super.initState();
    _checkDistance();
  }

  Future<void> _checkDistance() async {
    final rawBooking = await ref
        .read(bookingRepositoryProvider)
        .getRawBooking(widget.bookingId);
    final reqLat = (rawBooking?['latitude'] as num?)?.toDouble();
    final reqLng = (rawBooking?['longitude'] as num?)?.toDouble();

    if (reqLat != null && reqLng != null) {
      try {
        final pos = await LiveLocationRepository.getCurrentPosition();
        if (pos != null) {
          final dist = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            reqLat,
            reqLng,
          );
          if (mounted) {
            setState(() {
              _distanceMeters = dist;
              _calculatingDistance = false;
            });
            return;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _calculatingDistance = false);
    }
  }

  void _ignoreRequest() {
    ref
        .read(ignoredRequestsProvider.notifier)
        .update((set) => {...set, widget.bookingId});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Request ignored.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(bookingDetailsProvider(widget.bookingId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_off_outlined),
            tooltip: 'Ignore Request',
            onPressed: _ignoreRequest,
          ),
        ],
      ),
      body: a.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (b) {
          if (b == null) return const Center(child: Text('Request not found'));
          final customer = b['customer'] as Map?;
          final vehicle = b['vehicle'] as Map?;
          final photos =
              (b['photo_urls'] as List?)?.map((e) => e.toString()).toList() ??
              [];

          final bool isOutOfRange =
              _distanceMeters != null && _distanceMeters! > 5000.0;
          final String? distanceKmStr = _distanceMeters != null
              ? (_distanceMeters! / 1000.0).toStringAsFixed(1)
              : null;

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                customer?['full_name']?.toString() ?? 'Customer',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (vehicle != null)
                Text(
                  '${vehicle['make_model'] ?? ''} · ${vehicle['license_plate'] ?? ''}',
                  style: TextStyle(color: context.colors.textMuted),
                ),
              const SizedBox(height: 18),
              const Text('SERVICE'),
              Text(b['service_title']?.toString() ?? ''),
              const SizedBox(height: 16),
              const Text('ISSUE DESCRIPTION'),
              Text(
                b['description']?.toString().isNotEmpty == true
                    ? b['description'].toString()
                    : 'No description provided',
              ),
              const SizedBox(height: 16),
              if (photos.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: photos
                      .map(
                        (u) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            u,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📍 ${b['pickup_address'] ?? ''}'),
                    if (!_calculatingDistance && distanceKmStr != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        isOutOfRange
                            ? '⚠️ $distanceKmStr km away (Outside 5 km service limit)'
                            : '✅ $distanceKmStr km away (Within 5 km range)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOutOfRange ? Colors.orange : scheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CUSTOMER BUDGET'),
                    Text(
                      'PKR ${((b['budget_price'] as num?) ?? 0).toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isOutOfRange) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'This request is beyond your 5 km service range. You can ignore or skip this request.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                OutlineActionButton(
                  label: 'Ignore Request',
                  isDanger: true,
                  onPressed: _ignoreRequest,
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: AccentButton(
                        label: 'Send Offer',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SendOfferScreen(bookingId: widget.bookingId),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlineActionButton(
                        label: 'Ignore',
                        isDanger: true,
                        onPressed: _ignoreRequest,
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
