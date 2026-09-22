import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/providers/chat_provider.dart';
import '../../cores/providers/live_location_provider.dart';
import '../../cores/repositories/live_location_repository.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/live_google_map.dart';
import '../call/call_screen.dart';
import '../customer/chat_screen.dart';
import 'job_completed_screen.dart';
import 'mechanic_home_screen.dart';

class OnTheWayScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const OnTheWayScreen({super.key, required this.bookingId});

  @override
  ConsumerState<OnTheWayScreen> createState() => _OnTheWayScreenState();
}

class _OnTheWayScreenState extends ConsumerState<OnTheWayScreen>
    with WidgetsBindingObserver {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  LiveLocation? _myLocation;
  bool _starting = true;
  bool _locationServiceOff = false;
  bool _locationPermissionDenied = false;
  bool _locationPermissionDeniedForever = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchLocationService();
    _startLocationTracking();
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
      _startLocationTracking();
    }
  }

  Future<void> _startLocationTracking() async {
    final mechanicId = ref.read(authProvider).user?.id;
    if (mechanicId == null) {
      if (mounted) setState(() => _starting = false);
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(() {
          _locationServiceOff = true;
          _locationError = null;
          _starting = false;
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
          _locationServiceOff = false;
          _locationPermissionDenied = permission == LocationPermission.denied;
          _locationPermissionDeniedForever =
              permission == LocationPermission.deniedForever;
          _locationError = null;
          _starting = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _locationServiceOff = false;
        _locationPermissionDenied = false;
        _locationPermissionDeniedForever = false;
        _locationError = null;
        _starting = true;
      });
    }

    try {
      // Mark job status as on_the_way when mechanic starts tracking
      await ref
          .read(bookingRepositoryProvider)
          .updateStatus(widget.bookingId, 'on_the_way');

      final repository = ref.read(liveLocationRepositoryProvider);
      final firstPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await repository.updateMechanicLocation(
        bookingId: widget.bookingId,
        mechanicId: mechanicId,
        position: firstPosition,
      );
      _setMyLocation(mechanicId, firstPosition);

      await _positionSubscription?.cancel();
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((position) async {
            try {
              await repository.updateMechanicLocation(
                bookingId: widget.bookingId,
                mechanicId: mechanicId,
                position: position,
              );
              _setMyLocation(mechanicId, position);
            } catch (e) {
              if (mounted) {
                setState(() => _locationError = 'GPS update failed: $e');
              }
            }
          });
    } catch (e) {
      if (mounted) {
        setState(() => _locationError = 'Unable to start live location: $e');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
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
        await _startLocationTracking();
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
        _startLocationTracking();
      } else {
        _positionSubscription?.cancel();
        _positionSubscription = null;
        setState(() {
          _locationServiceOff = true;
          _starting = false;
        });
      }
    });
  }

  void _setMyLocation(String mechanicId, Position position) {
    if (!mounted) return;
    setState(() {
      _myLocation = LiveLocation(
        bookingId: widget.bookingId,
        mechanicId: mechanicId,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading.isFinite ? position.heading : 0,
        updatedAt: DateTime.now(),
      );
    });
  }

  LatLng? _customerLocation(Map<String, dynamic>? booking) {
    final lat = (booking?['latitude'] as num?)?.toDouble();
    final lng = (booking?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailsProvider(widget.bookingId));
    final liveLocation = ref
        .watch(bookingLiveLocationProvider(widget.bookingId))
        .valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('On The Way')),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (booking) {
          final customer = booking?['customer'] as Map?;
          final name = customer?['full_name']?.toString() ?? 'Customer';
          final customerId =
              (customer?['id'] ?? booking?['customer_id'])?.toString() ?? '';
          final initials = name
              .split(' ')
              .where((x) => x.isNotEmpty)
              .take(2)
              .map((x) => x[0])
              .join()
              .toUpperCase();

          final liveCustomer = liveLocation?.hasCustomerLocation == true
              ? LatLng(
                  liveLocation!.customerLatitude!,
                  liveLocation.customerLongitude!,
                )
              : _customerLocation(booking);

          // Real-Time Auto Navigation when Customer completes payment OR cancels
          final status = booking?['status']?.toString();

          if (status == 'completed') {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _positionSubscription?.cancel();
              _positionSubscription = null;
              if (!mounted) return;
              final currentContext = context;
              if (!currentContext.mounted) return;
              Navigator.pushAndRemoveUntil(
                currentContext,
                MaterialPageRoute(
                  builder: (_) => JobCompletedScreen(bookingId: widget.bookingId),
                ),
                (route) => false,
              );
            });
          } else if (status == 'cancelled') {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _positionSubscription?.cancel();
              _positionSubscription = null;
              if (!mounted) return;
              final currentContext = context;
              if (!currentContext.mounted) return;

              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(
                  content: Text('Booking was cancelled by the customer.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );

              Navigator.pushAndRemoveUntil(
                currentContext,
                MaterialPageRoute(
                  builder: (_) => const MechanicHomeScreen(),
                ),
                (route) => false,
              );
            });
          }

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
                    customerLocation: liveCustomer,
                    mechanicLocation: _myLocation,
                  ),
                ),
                if (_locationServiceOff ||
                    _locationPermissionDenied ||
                    _locationPermissionDeniedForever)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_off_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _locationPermissionDeniedForever
                                  ? 'Location permission is permanently denied. Enable it in app settings.'
                                  : _locationPermissionDenied
                                  ? 'Location permission is required for live navigation.'
                                  : 'GPS is turned off. Turn on Location to start live navigation.',
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
                  )
                else if (_starting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Starting live GPS tracking...'),
                  )
                else if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _locationError!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                Text(
                  booking?['pickup_address']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                        onPressed: customerId.isEmpty
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    bookingId: widget.bookingId,
                                    otherUserId: customerId,
                                    otherName: name,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Waiting for customer payment & job completion...',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
