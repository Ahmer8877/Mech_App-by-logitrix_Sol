import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase setup. Call SupabaseConfig.init() once in main() before
/// runApp(), then use `supabase` (the shortcut getter below) anywhere to
/// access the client — same pattern as Firebase's FirebaseFirestore.instance.
///
/// Get these two values from your Supabase project dashboard:
/// Settings → API → Project URL, and Settings → API → Publishable key
/// (previously called the "anon" key — same permissions, new name).
class SupabaseConfig {
  SupabaseConfig._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseKey =>
      dotenv.env['PUBLISHABLE_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static Future<void> init() async {
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    } else {
      debugPrint('Supabase credentials missing in .env file.');
    }
  }
}

/// Shortcut so screens can write `supabase.from('bookings')...` instead of
/// `Supabase.instance.client.from('bookings')...`
SupabaseClient get supabase => Supabase.instance.client;
