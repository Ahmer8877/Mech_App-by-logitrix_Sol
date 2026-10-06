import 'package:flutter/material.dart';
import 'widgets/app_text.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:internationalization/internationalization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mech_app/cores/config/dotenv_config.dart';
import 'package:mech_app/cores/config/supabase_config.dart';
import 'cores/providers/connectivity_provider.dart';
import 'cores/providers/theme_provider.dart';
import 'cores/providers/language_provider.dart';
import 'cores/services/notification_push_service.dart';
import 'cores/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ///firebase initialization
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// dotenv initialization
  await DotenvConfig.init();

  /// supabase initialization
  await SupabaseConfig.init();

  /// OS-level push notification initialization.
  /// This is a no-op until ONESIGNAL_APP_ID is configured.
  await NotificationPushService.instance.initialize();

  /// app initialization wrapped in Riverpod ProviderScope
  runApp(const ProviderScope(child: MechXApp()));
}

class MechXApp extends ConsumerWidget {
  const MechXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(languageProvider);
    const supportedLocales = [Locale('en'), Locale('ur')];

    return MaterialApp(
      navigatorKey: AppNavigator.key,
      title: 'MechX',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: [
        InternationalizationDelegate(
          suportedLocales: supportedLocales,
          translationsPath: 'assets/translations/',
        ),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const SplashScreen(),
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final internetAsync = ref.watch(internetConnectedProvider);
            final isConnected = internetAsync.valueOrNull ?? true;

            return Column(
              children: [
                if (!isConnected)
                  Container(
                    width: double.infinity,
                    color: Colors.red[700],
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: AppText(
                              'No Internet Connection. Please check your network.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            );
          },
        );
      },
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


