import 'package:supabase_flutter/supabase_flutter.dart';

class RoutesRepository {
  final SupabaseClient client;
  RoutesRepository(this.client);

  Future<RouteResult?> getDrivingRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final response = await client.functions.invoke(
      'compute-route',
      body: {
        'origin': {'latitude': originLatitude, 'longitude': originLongitude},
        'destination': {
          'latitude': destinationLatitude,
          'longitude': destinationLongitude,
        },
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final encoded = data['encodedPolyline']?.toString();
    if (encoded == null || encoded.isEmpty) return null;
    return RouteResult(
      points: decodePolyline(encoded),
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: _parseDuration(data['duration']?.toString()),
    );
  }

  double? _parseDuration(String? value) {
    if (value == null) return null;
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)s').firstMatch(value);
    return match == null ? null : double.tryParse(match.group(1)!);
  }
}

class RouteResult {
  final List<({double latitude, double longitude})> points;
  final double? distanceMeters;
  final double? durationSeconds;
  const RouteResult({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
  });
}

List<({double latitude, double longitude})> decodePolyline(String encoded) {
  final result = <({double latitude, double longitude})>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var shift = 0;
    var value = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      value |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index < encoded.length);
    lat += (value & 1) != 0 ? ~(value >> 1) : (value >> 1);

    shift = 0;
    value = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      value |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index < encoded.length);
    lng += (value & 1) != 0 ? ~(value >> 1) : (value >> 1);

    result.add((latitude: lat / 1e5, longitude: lng / 1e5));
  }
  return result;
}
