import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/providers/chat_provider.dart';
import '../../cores/providers/live_location_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_atoms.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/live_google_map.dart';
import '../call/call_screen.dart';
import 'chat_screen.dart';
import 'customer_home_screen.dart';
import 'payment_method_screen.dart';
import 'payment_rating_screen.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const TrackingScreen({super.key, required this.bookingId});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with WidgetsBindingObserver {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  bool _locationStarted = false;
  bool _locationServiceOff = false;
  bool _locationPermissionDenied = false;
  bool _locationPermissionDeniedForever = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchLocationService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _locationStarted = false;
      _startCustomerTracking();
    }
  }

  Future<void> _startCustomerTracking() async {
    final customerId = ref.read(authProvider).user?.id;
    if (customerId == null) return;

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(() {
          _locationStarted = false;
          _locationServiceOff = true;
          _locationPermissionDenied = false;
        });
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationStarted = false;
          _locationServiceOff = false;
          _locationPermissionDenied = permission == LocationPermission.denied;
          _locationPermissionDeniedForever =
              permission == LocationPermission.deniedForever;
        });
      }
      return;
    }

    if (_locationStarted) return;
    _locationStarted = true;

    if (mounted) {
      setState(() {
        _locationServiceOff = false;
        _locationPermissionDenied = false;
        _locationPermissionDeniedForever = false;
      });
    }

    final repo = ref.read(liveLocationRepositoryProvider);
    try {
      final first = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await repo.updateCustomerLocation(
        bookingId: widget.bookingId,
        customerId: customerId,
        position: first,
      );
      await _positionSubscription?.cancel();
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((position) async {
            try {
              await repo.updateCustomerLocation(
                bookingId: widget.bookingId,
                customerId: customerId,
                position: position,
              );
            } catch (_) {}
          });
    } catch (e) {
      _locationStarted = false;
      if (mounted) {
        setState(() => _locationServiceOff = true);
      }
    }
  }

  Future<void> _openLocationSettings() async {
    if (_locationPermissionDeniedForever) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.openLocationSettings();
    }

    // Seamless GPS auto-check when returning from location settings window
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      if (await Geolocator.isLocationServiceEnabled()) {
        _locationStarted = false;
        await _startCustomerTracking();
        break;
      }
    }
  }

  void _watchLocationService() {
    _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((
      status,
    ) {
      if (!mounted) return;
      if (status == ServiceStatus.enabled) {
        _locationStarted = false;
        _startCustomerTracking();
      } else {
        setState(() {
          _locationStarted = false;
          _locationServiceOff = true;
        });
        _positionSubscription?.cancel();
        _positionSubscription = null;
      }
    });
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(bookingRepositoryProvider).cancel(widget.bookingId);
      ref.invalidate(bookingsProvider);
      ref.invalidate(bookingDetailsProvider(widget.bookingId));

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cancel booking: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final booking = ref.watch(bookingDetailsProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Status')),
      body: booking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Booking not found'));
          }

          final mechanic = data['mechanic'];
          final mechanicMap = mechanic is Map ? mechanic : null;
          final name = mechanicMap?['full_name']?.toString() ?? 'Mechanic';
          final mechanicId = mechanicMap?['id']?.toString() ?? '';
          final initials = name
              .split(' ')
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0])
              .join()
              .toUpperCase();
          final status = data['status']?.toString() ?? 'pending';
          if (status == 'accepted' ||
              status == 'on_the_way' ||
              status == 'in_progress') {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _startCustomerTracking(),
            );
          } else if (status == 'cancelled') {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _positionSubscription?.cancel();
              _positionSubscription = null;
              if (!mounted) return;
              final currentContext = context;
              if (!currentContext.mounted) return;

              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(
                  content: Text('Booking was cancelled. Returning to home.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );

              Navigator.pushAndRemoveUntil(
                currentContext,
                MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
                (route) => false,
              );
            });
          }
          final service = data['service_title']?.toString() ?? 'Service';
          final address = data['pickup_address']?.toString() ?? '';
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final live = ref
              .watch(bookingLiveLocationProvider(widget.bookingId))
              .valueOrNull;
          final customerLocation = live?.hasCustomerLocation == true
              ? LatLng(live!.customerLatitude!, live.customerLongitude!)
              : ((lat != null && lng != null) ? LatLng(lat, lng) : null);
          final mechanicLocation = live?.hasMechanicLocation == true
              ? live
              : null;

          final activeUserId = ref.watch(authProvider).user?.id ?? '';
          final unreadChat = ref.watch(
            unreadBookingChatCountProvider((
              bookingId: widget.bookingId,
              activeUserId: activeUserId,
            )),
          );

          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Expanded(
                  child: LiveGoogleMap(
                    customerLocation: customerLocation,
                    mechanicLocation: mechanicLocation,
                  ),
                ),
                if (_locationServiceOff ||
                    _locationPermissionDenied ||
                    _locationPermissionDeniedForever)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: AppCard(
                      child: Row(
                        children: [
                          const Icon(Icons.location_off_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _locationPermissionDeniedForever
                                  ? 'Location permission is permanently denied. Enable it in app settings.'
                                  : _locationPermissionDenied
                                  ? 'Location permission is required to share your live location.'
                                  : 'GPS is turned off. Turn on Location to show your live position.',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          TextButton(
                            onPressed: _openLocationSettings,
                            child: Text(
                              _locationPermissionDeniedForever
                                  ? 'Settings'
                                  : 'Turn On',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(initials.isEmpty ? 'M' : initials),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$service · $status',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colors.textMuted,
                              ),
                            ),
                            if (address.isNotEmpty)
                              Text(
                                address,
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlineActionButton(
                        label: 'Call',
                        onPressed: mechanicId.isEmpty
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CallScreen(
                                    name: name,
                                    initials: initials,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlineActionButton(
                        label: unreadChat > 0 ? 'Chat ($unreadChat)' : 'Chat',
                        icon: unreadChat > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadChat',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onPressed: mechanicId.isEmpty
                            ? null
                            : () =>
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        bookingId: widget.bookingId,
                                        otherUserId: mechanicId,
                                        otherName: name,
                                      ),
                                    ),
                                  ).then((_) {
                                    ref.invalidate(
                                      chatMessagesProvider(widget.bookingId),
                                    );
                                  }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (status == 'completed')
                  AccentButton(
                    label: 'Rating',
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PaymentRatingScreen(bookingId: widget.bookingId),
                      ),
                    ),
                  )
                else if (status != 'cancelled')
                  Row(
                    children: [
                      Expanded(
                        child: AccentButton(
                          label: 'Pay & Complete',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentMethodScreen(
                                bookingId: widget.bookingId,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlineActionButton(
                          label: 'Cancel Booking',
                          isDanger: true,
                          onPressed: () => _cancel(context, ref),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
