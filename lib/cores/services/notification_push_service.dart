import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../screens/customer/offers_screen.dart';
import '../../screens/customer/tracking_screen.dart';
import '../../screens/mechanic/mechanic_bookings_screen.dart';
import '../../screens/notification/notifications_screen.dart';

class AppNavigator {
  AppNavigator._();
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
}

/// OS-level push notification integration.
/// Supabase remains the source of truth for in-app notifications.
class NotificationPushService {
  NotificationPushService._();
  static final NotificationPushService instance = NotificationPushService._();

  StreamSubscription<AuthState>? _authSubscription;
  bool _initialized = false;
  Map<String, dynamic>? _pendingNotificationData;

  String get _appId => dotenv.env['ONESIGNAL_APP_ID']?.trim() ?? '';

  Future<void> initialize() async {
    if (_initialized || _appId.isEmpty || kIsWeb) {
      if (_appId.isEmpty) {
        debugPrint('OneSignal disabled: ONESIGNAL_APP_ID is not configured.');
      }
      return;
    }

    try {
      await OneSignal.initialize(_appId);
      OneSignal.Notifications.addClickListener(_onNotificationClicked);
      await OneSignal.Notifications.requestPermission(false);

      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (state) async {
          final user = state.session?.user;
          if (user != null) {
            await _loginUser(user.id);
          } else {
            await _logoutUser();
          }
        },
      );

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await _loginUser(currentUser.id);
      }

      _initialized = true;
      _flushPendingNotification();
      debugPrint('OneSignal push service initialized.');
    } catch (e, stackTrace) {
      debugPrint('OneSignal initialization failed: $e');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _loginUser(String userId) async {
    try {
      await OneSignal.login(userId);
      debugPrint('OneSignal user linked: $userId');
    } catch (e) {
      debugPrint('OneSignal user linking failed: $e');
    }
  }

  Future<void> _logoutUser() async {
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('OneSignal logout failed: $e');
    }
  }

  void _onNotificationClicked(OSNotificationClickEvent event) {
    final data = Map<String, dynamic>.from(
      event.notification.additionalData ?? const <String, dynamic>{},
    );

    if (AppNavigator.key.currentState == null) {
      _pendingNotificationData = data;
      return;
    }

    _openNotificationTarget(data);
  }

  void _flushPendingNotification() {
    final data = _pendingNotificationData;
    if (data == null) return;
    _pendingNotificationData = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openNotificationTarget(data);
    });
  }

  void _openNotificationTarget(Map<String, dynamic> data) {
    final navigator = AppNavigator.key.currentState;
    if (navigator == null) {
      _pendingNotificationData = data;
      return;
    }

    final type = (data['type'] ?? data['notification_type'] ?? '')
        .toString()
        .toLowerCase();
    final bookingId = (data['booking_id'] ?? '').toString();

    final Widget destination;
    if (bookingId.isNotEmpty &&
        (type.contains('offer') || type == 'new_booking_offer')) {
      destination = OffersScreen(bookingId: bookingId);
    } else if (bookingId.isNotEmpty &&
        (type.contains('way') || type.contains('tracking') || type == 'assigned')) {
      destination = TrackingScreen(bookingId: bookingId);
    } else if (type.contains('booking') || type.contains('job')) {
      destination = const MechanicBookingsScreen();
    } else {
      destination = const NotificationsScreen();
    }

    navigator.push(MaterialPageRoute(builder: (_) => destination));
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}
