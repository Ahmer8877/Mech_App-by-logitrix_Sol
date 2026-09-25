import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cores/repositories/live_location_repository.dart';
import '../cores/repositories/routes_repository.dart';
import '../cores/theme/app_theme.dart';

class LiveGoogleMap extends StatefulWidget {
  final LatLng? customerLocation;
  final LiveLocation? mechanicLocation;
  final bool showCustomerMarker;
  final bool showMechanicMarker;

  const LiveGoogleMap({
    super.key,
    this.customerLocation,
    this.mechanicLocation,
    this.showCustomerMarker = true,
    this.showMechanicMarker = true,
  });

  @override
  State<LiveGoogleMap> createState() => _LiveGoogleMapState();
}

class _LiveGoogleMapState extends State<LiveGoogleMap> {
  GoogleMapController? _controller;
  List<LatLng> _routePoints = const [];
  bool _routeLoading = false;
  double? _lastRouteLat;
  double? _lastRouteLng;
  double? _lastDestinationLat;
  double? _lastDestinationLng;

  static const _fallback = LatLng(31.5204, 74.3587);

  @override
  void didUpdateWidget(covariant LiveGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final mechanic = _mechanicLatLng(widget.mechanicLocation);
    final customerChanged =
        oldWidget.customerLocation != widget.customerLocation;
    final mechanicChanged =
        oldWidget.mechanicLocation != widget.mechanicLocation;

    if (!customerChanged && !mechanicChanged) return;

    if (mechanic != null) {
      _refreshRoadRoute(force: true);
    }

    // When GPS becomes available, move the camera to the real location smoothly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller == null) return;
      if (widget.customerLocation != null && mechanic != null) {
        _fitMarkers();
      } else if (mechanic != null) {
        _controller!.animateCamera(CameraUpdate.newLatLngZoom(mechanic, 15));
      } else if (widget.customerLocation != null) {
        _controller!.animateCamera(
          CameraUpdate.newLatLngZoom(widget.customerLocation!, 15),
        );
      }
    });
  }

  LatLng? _mechanicLatLng(LiveLocation? location) {
    if (location == null || !location.hasMechanicLocation) return null;
    return LatLng(location.latitude!, location.longitude!);
  }

  Set<Polyline> _polylines() {
    final customer = widget.customerLocation;
    final mechanic = _mechanicLatLng(widget.mechanicLocation);
    if (customer == null || mechanic == null) return const <Polyline>{};
    final points = _routePoints.length >= 2
        ? _routePoints
        : [mechanic, customer];
    return {
      Polyline(
        polylineId: const PolylineId('live_route'),
        points: points,
        width: 6,
        color: const Color(0xFF0E4747), // Visible Teal Accent Line
        geodesic: true,
      ),
    };
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLon = (lon2 - lon1) * 3.141592653589793 / 180;
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(lat1 * 3.141592653589793 / 180) *
            math.cos(lat2 * 3.141592653589793 / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _refreshRoadRoute({bool force = false}) async {
    final customer = widget.customerLocation;
    final mechanic = _mechanicLatLng(widget.mechanicLocation);
    if (customer == null || mechanic == null || _routeLoading) return;

    if (!force &&
        _lastRouteLat != null &&
        _lastRouteLng != null &&
        _lastDestinationLat != null &&
        _lastDestinationLng != null) {
      final moved = _distanceMeters(
        _lastRouteLat!,
        _lastRouteLng!,
        mechanic.latitude,
        mechanic.longitude,
      );
      final destinationMoved = _distanceMeters(
        _lastDestinationLat!,
        _lastDestinationLng!,
        customer.latitude,
        customer.longitude,
      );
      if (moved < 30 && destinationMoved < 15) return;
    }

    _routeLoading = true;
    try {
      final result = await RoutesRepository(Supabase.instance.client)
          .getDrivingRoute(
            originLatitude: mechanic.latitude,
            originLongitude: mechanic.longitude,
            destinationLatitude: customer.latitude,
            destinationLongitude: customer.longitude,
          );
      if (!mounted) return;
      if (result != null && result.points.length >= 2) {
        setState(() {
          _routePoints = result.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(growable: false);
          _lastRouteLat = mechanic.latitude;
          _lastRouteLng = mechanic.longitude;
          _lastDestinationLat = customer.latitude;
          _lastDestinationLng = customer.longitude;
        });
      }
    } catch (_) {
    } finally {
      _routeLoading = false;
    }
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};

    if (widget.showCustomerMarker && widget.customerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer_pickup'),
          position: widget.customerLocation!,
          infoWindow: const InfoWindow(title: 'Customer Pickup Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    final mechanic = _mechanicLatLng(widget.mechanicLocation);
    if (widget.showMechanicMarker && mechanic != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('mechanic_live'),
          position: mechanic,
          infoWindow: const InfoWindow(title: 'Mechanic Live Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          rotation: widget.mechanicLocation!.heading,
        ),
      );
    }

    return markers;
  }

  LatLng _initialTarget() {
    final mechanic = _mechanicLatLng(widget.mechanicLocation);
    return mechanic ?? widget.customerLocation ?? _fallback;
  }

  void _fitMarkers() {
    final points = <LatLng>[];
    if (widget.customerLocation != null) points.add(widget.customerLocation!);
    final mechanic = _mechanicLatLng(widget.mechanicLocation);
    if (mechanic != null) points.add(mechanic);

    if (points.length < 2) {
      if (points.length == 1) {
        _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 15),
        );
      }
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Guard against continent-spanning distances on emulators
    final latDelta = (maxLat - minLat).abs();
    final lngDelta = (maxLng - minLng).abs();
    if (latDelta > 5.0 || lngDelta > 5.0) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(mechanic ?? widget.customerLocation!, 14),
      );
      return;
    }

    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.005, minLng - 0.005),
          northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
        ),
        60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyLocation =
        widget.customerLocation != null || widget.mechanicLocation != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialTarget(),
              zoom: hasAnyLocation ? 14 : 11,
            ),
            markers: _markers(),
            polylines: _polylines(),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) {
              _controller = controller;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fitMarkers();
                _refreshRoadRoute(force: true);
              });
            },
          ),
          if (!hasAnyLocation)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.78),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Location is not available yet.\nWaiting for GPS...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.mechanicLocation != null)
            Positioned(
              top: 12,
              left: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 9, color: Colors.green),
                      SizedBox(width: 6),
                      Text('Mechanic live'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
