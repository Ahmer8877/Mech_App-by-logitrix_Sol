import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../cores/config/supabase_config.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/booking_draft_provider.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/providers/services_provider.dart';
import '../../cores/repositories/booking_repository.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/live_google_map.dart';
import '../../widgets/step_progress.dart';
import 'offers_screen.dart';

class SetLocationScreen extends ConsumerStatefulWidget {
  const SetLocationScreen({super.key});

  @override
  ConsumerState<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends ConsumerState<SetLocationScreen> {
  final _addressController = TextEditingController();
  final _budgetController = TextEditingController();
  bool _saving = false;
  bool _locating = true;
  String? _locationError;
  Position? _currentPosition;

  Future<void> _createBooking() async {
    final draft = ref.read(bookingDraftProvider);
    final userId = ref.read(authProvider).user?.id;
    final services = ref.read(servicesProvider).valueOrNull ?? const [];

    if (userId == null || draft.vehicleId == null || draft.serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Please select a vehicle and service first.'),
        ),
      );
      return;
    }

    final matchingServices = services.where(
      (service) => service.id == draft.serviceId,
    );
    if (matchingServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Selected service is no longer available.'),
        ),
      );
      return;
    }

    final service = matchingServices.first;
    final address = _addressController.text.trim();
    final enteredBudget = double.tryParse(_budgetController.text.trim());
    final budget = enteredBudget ?? service.basePrice;

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Please turn on location and allow GPS before continuing.'),
        ),
      );
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Please enter pickup address')),
      );
      return;
    }

    if (budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Please enter a valid budget.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final bookingId = await BookingRepository(supabase).createBooking(
        customerId: userId,
        vehicleId: draft.vehicleId!,
        serviceId: draft.serviceId!,
        serviceTitle: service.title,
        description: draft.description,
        photoUrls: draft.photoUrls,
        address: address,
        budget: budget,
        paymentMethod: 'Cash',
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );

      ref.read(bookingDraftProvider.notifier).setLocation(address);
      ref.invalidate(bookingsProvider);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OffersScreen(bookingId: bookingId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Could not create the request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _locating = false;
          _locationError = 'GPS is turned off.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locating = false;
          _locationError =
              'Location permission is required to show your pickup point.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locating = false;
        _locationError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = 'Could not get current location.';
      });
    }
  }

  Future<void> _openLocationSettings() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.openLocationSettings();
    }
    // Re-check immediately after returning so the map can recover without leaving the screen.
    for (var i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await _loadCurrentLocation();
      if (_currentPosition != null) return;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: const FlowAppBar(title: 'Pickup Location'),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepProgress(total: 5, current: 4),
            Expanded(
              child: Stack(
                children: [
                  LiveGoogleMap(
                    currentLocation: _currentPosition == null
                        ? null
                        : LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                    locationServiceEnabled:
                        _locationError != 'GPS is turned off.',
                    locationPermissionDenied: _locationError != null,
                    // The explicit card below owns the GPS action on this screen.
                    onEnableLocation: null,
                    customerLocation: _currentPosition == null
                        ? null
                        : LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                    showMechanicMarker: false,
                  ),
                  if (_locating)
                    const Positioned(
                      top: 12,
                      left: 12,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: AppText('Getting your location...'),
                        ),
                      ),
                    ),
                  if (!_locating && _currentPosition == null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppText(
                                _locationError ?? 'Location is required to continue.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              AccentButton(
                                label: 'Turn on location',
                                onPressed: _openLocationSettings,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Pickup address',
                hintText: 'Enter your current address',
                filled: true,
                fillColor: colors.surface2,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Your budget (optional)',
                prefixText: 'PKR ',
                filled: true,
                fillColor: colors.surface2,
              ),
            ),
            const SizedBox(height: 14),
            AccentButton(
              label: _saving
                  ? 'Creating request...'
                  : 'Confirm & Find Mechanics',
              onPressed: _saving ? null : _createBooking,
            ),
          ],
        ),
      ),
    );
  }
}
