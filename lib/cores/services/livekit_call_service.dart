import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-authorized LiveKit booking-call integration.
///
/// LiveKit API credentials and signing secrets never live in the mobile app.
/// Supabase Edge Functions authorize the booking participant and mint the
/// short-lived participant token.
class LiveKitCallService {
  LiveKitCallService._();
  static final LiveKitCallService instance = LiveKitCallService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<CallSession> startCall({required String bookingId}) async {
    final response = await _supabase.functions.invoke(
      'livekit-start-call',
      body: {'booking_id': bookingId},
    );
    return _sessionFromResponse(response.data, 'start-call');
  }

  Future<CallSession> getSession(String sessionId) async {
    final row = await _supabase
        .from('call_sessions')
        .select()
        .eq('id', sessionId)
        .single();
    return CallSession.fromMap(row);
  }

  /// Returns recent calls belonging to the signed-in user only.
  /// RLS on call_sessions remains the authoritative access-control boundary.
  Future<List<CallSession>> getCallHistory({int limit = 50}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null)
      throw StateError('Please sign in to view call history.');

    final safeLimit = limit.clamp(1, 100).toInt();
    // Query each participant direction separately. This avoids PostgREST .or
    // filter parsing issues and keeps the result compatible with participant
    // SELECT policies. Merge and deduplicate in case a row matches both sides.
    final callerRows = await _supabase
        .from('call_sessions')
        .select()
        .eq('caller_id', userId)
        .order('created_at', ascending: false)
        .limit(safeLimit);
    final calleeRows = await _supabase
        .from('call_sessions')
        .select()
        .eq('callee_id', userId)
        .order('created_at', ascending: false)
        .limit(safeLimit);

    final byId = <String, Map<String, dynamic>>{};
    for (final row in [...callerRows, ...calleeRows]) {
      final map = Map<String, dynamic>.from(row);
      byId[map['id'].toString()] = map;
    }
    final sessionMaps = byId.values.toList()
      ..sort(
        (a, b) => (b['created_at']?.toString() ?? '').compareTo(
          a['created_at']?.toString() ?? '',
        ),
      );
    if (sessionMaps.length > safeLimit) {
      sessionMaps.removeRange(safeLimit, sessionMaps.length);
    }
    final participantIds = <String>{};
    for (final row in sessionMaps) {
      participantIds.add(row['caller_id'].toString());
      participantIds.add(row['callee_id'].toString());
    }

    // Resolve display names in one query rather than one query per call.
    final names = <String, String>{};
    if (participantIds.isNotEmpty) {
      try {
        final profiles = await _supabase
            .from('profiles')
            .select('id,full_name')
            .inFilter('id', participantIds.toList());
        for (final profile in profiles) {
          final id = profile['id']?.toString();
          final name = profile['full_name']?.toString().trim();
          if (id != null && name != null && name.isNotEmpty) names[id] = name;
        }
      } catch (error) {
        debugPrint('Call history names could not be loaded: $error');
      }
    }

    return sessionMaps
        .map((row) {
          final callerId = row['caller_id'].toString();
          final calleeId = row['callee_id'].toString();
          return CallSession.fromMap({
            ...row,
            'caller_name': names[callerId] ?? 'MechX user',
            'callee_name': names[calleeId] ?? 'MechX user',
          });
        })
        .toList(growable: false);
  }

  Stream<CallSession> watchSession(String sessionId) {
    return _supabase
        .from('call_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((rows) => rows.isEmpty ? null : CallSession.fromMap(rows.first))
        .where((session) => session != null)
        .cast<CallSession>();
  }

  Future<CallSession> acceptCall(String sessionId) async {
    final response = await _supabase.functions.invoke(
      'livekit-update-call',
      body: {'session_id': sessionId, 'action': 'accept'},
    );
    return _sessionFromResponse(response.data, 'accept-call');
  }

  Future<CallSession> rejectCall(String sessionId) async {
    final response = await _supabase.functions.invoke(
      'livekit-update-call',
      body: {'session_id': sessionId, 'action': 'reject'},
    );
    return _sessionFromResponse(response.data, 'reject-call');
  }

  Future<CallSession> markMissed(String sessionId) async {
    final response = await _supabase.functions.invoke(
      'livekit-update-call',
      body: {'session_id': sessionId, 'action': 'missed'},
    );
    return _sessionFromResponse(response.data, 'missed-call');
  }

  Future<void> endCall(String sessionId) async {
    await _supabase.functions.invoke(
      'livekit-update-call',
      body: {'session_id': sessionId, 'action': 'end'},
    );
  }

  Future<String?> getOtherParticipantAvatarUrl({
    required String callerId,
    required String calleeId,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return null;

    final otherId = currentUserId == callerId ? calleeId : callerId;
    final row = await _supabase
        .from('profiles')
        .select('avatar_url')
        .eq('id', otherId)
        .maybeSingle();

    final value = row?['avatar_url']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<LiveKitCredentials> getCredentials({required String sessionId}) async {
    final response = await _supabase.functions.invoke(
      'livekit-token',
      body: {'session_id': sessionId},
    );

    if (response.data is! Map) {
      throw StateError('Invalid LiveKit credentials response.');
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    final rawUrl = data['server_url']?.toString().trim() ?? '';
    final token = data['participant_token']?.toString().trim() ?? '';

    if (rawUrl.isEmpty) {
      throw StateError(
        'LiveKit server URL is empty: ${data['error'] ?? 'unknown error'}',
      );
    }
    if (token.isEmpty) {
      throw StateError(
        'LiveKit participant token is empty: ${data['error'] ?? 'unknown error'}',
      );
    }

    return LiveKitCredentials(
      serverUrl: _normalizeLiveKitUrl(rawUrl),
      participantToken: token,
    );
  }

  String _normalizeLiveKitUrl(String value) {
    var url = value.trim();

    if (url.startsWith('"') && url.endsWith('"') && url.length >= 2) {
      url = url.substring(1, url.length - 1).trim();
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw StateError('Invalid LiveKit server URL.');
    }

    final scheme = uri.scheme.toLowerCase();
    final port = uri.hasPort && uri.port > 0 ? ':${uri.port}' : '';
    final path = uri.path == '/' ? '' : uri.path;

    switch (scheme) {
      case 'https':
        return 'wss://${uri.host}$port$path';
      case 'http':
        return 'ws://${uri.host}$port$path';
      case 'wss':
      case 'ws':
        return '$scheme://${uri.host}$port$path';
      default:
        throw StateError('Invalid LiveKit URL scheme: ${uri.scheme}');
    }
  }

  Future<Room> connect(String serverUrl, String token) async {
    final normalizedUrl = _normalizeLiveKitUrl(serverUrl);
    final room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: false),
    );

    try {
      debugPrint('LiveKit connecting to: $normalizedUrl');
      await room.connect(normalizedUrl, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      return room;
    } catch (_) {
      await disconnect(room);
      rethrow;
    }
  }

  Future<void> disconnect(Room? room) async {
    try {
      await room?.disconnect();
    } catch (e) {
      debugPrint('LiveKit disconnect failed: $e');
    }
  }

  CallSession _sessionFromResponse(dynamic data, String operation) {
    if (data is! Map) {
      throw StateError('Invalid $operation response.');
    }
    final map = Map<String, dynamic>.from(data);
    if (map['error'] != null && map['id'] == null) {
      throw StateError(map['error'].toString());
    }
    return CallSession.fromMap(map);
  }
}

class CallSession {
  final String id;
  final String bookingId;
  final String callerId;
  final String calleeId;
  final String roomName;
  final String status;
  final String callerName;
  final String calleeName;
  final DateTime? createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  const CallSession({
    required this.id,
    required this.bookingId,
    required this.callerId,
    required this.calleeId,
    required this.roomName,
    required this.status,
    required this.callerName,
    required this.calleeName,
    this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  int get durationSeconds {
    final start = answeredAt;
    final end = endedAt;
    if (start == null) return 0;
    final seconds = (end ?? DateTime.now()).difference(start).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  factory CallSession.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text)?.toLocal();
    }

    return CallSession(
      id: map['id'].toString(),
      bookingId: map['booking_id'].toString(),
      callerId: map['caller_id'].toString(),
      calleeId: map['callee_id'].toString(),
      roomName: map['room_name'].toString(),
      status: map['status'].toString(),
      callerName: (map['caller_name'] ?? 'User').toString(),
      calleeName: (map['callee_name'] ?? 'User').toString(),
      createdAt: parseDate(map['created_at']),
      answeredAt: parseDate(map['answered_at']),
      endedAt: parseDate(map['ended_at']),
    );
  }
}

class LiveKitCredentials {
  final String serverUrl;
  final String participantToken;

  const LiveKitCredentials({
    required this.serverUrl,
    required this.participantToken,
  });
}
