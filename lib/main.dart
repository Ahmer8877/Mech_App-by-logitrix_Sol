import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mech_app/cores/config/dotenv_config.dart';
import 'package:mech_app/cores/config/supabase_config.dart';
import 'cores/providers/theme_provider.dart';
import 'cores/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// dotenv initialization
  await DotenvConfig.init();

  /// supabase initialization
  await SupabaseConfig.init();

  /// app initialization wrapped in Riverpod ProviderScope
  runApp(const ProviderScope(child: MechXApp()));
}

class MechXApp extends ConsumerWidget {
  const MechXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'MechX',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      },
    );
  }
}
