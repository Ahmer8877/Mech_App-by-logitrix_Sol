import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Periodic connectivity stream provider checking internet availability via Dart I/O socket lookup.
/// Emits `false` when internet is disconnected and `true` when connected.
/// Used globally in MaterialApp builder to display an offline warning banner for both customer and mechanic.
final internetConnectedProvider = StreamProvider<bool>((ref) async* {
  while (true) {
    bool isConnected = true;
    if (!kIsWeb) {
      try {
        final result = await InternetAddress.lookup('google.com').timeout(
          const Duration(seconds: 3),
        );
        isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        isConnected = false;
      }
    }
    yield isConnected;
    await Future.delayed(const Duration(seconds: 4));
  }
});
