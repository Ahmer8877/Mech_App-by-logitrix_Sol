import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts technical exceptions into short messages a customer can act on.
/// Detailed exceptions should still be written to debug logs, not shown in UI.
String friendlyErrorMessage(Object error) {
  if (error is SocketException || error is TimeoutException) {
    return 'Please check your internet connection and try again.';
  }
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email or password is incorrect. Please try again.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return 'We could not verify your account. Please try again.';
  }
  if (error is PostgrestException) {
    if (error.code == '42501' || error.code == 'PGRST301') {
      return 'You do not have permission to do that. Please contact support if this continues.';
    }
    return 'We could not save or load your information. Please try again.';
  }
  if (error is PlatformException) {
    return 'This feature is temporarily unavailable. Please try again.';
  }
  final message = error.toString().toLowerCase();
  if (message.contains('socketexception') ||
      message.contains('network is unreachable') ||
      message.contains('failed host lookup') ||
      message.contains('timed out')) {
    return 'Please check your internet connection and try again.';
  }
  if (message.contains('permission denied') ||
      message.contains('row-level security')) {
    return 'You do not have permission to complete this action.';
  }
  return 'Something went wrong. Please try again.';
}
