import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../cores/models/user_role.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/gauge_arc.dart';
import '../auth&role/role_select_screen.dart';
import '../customer/customer_home_screen.dart';
import '../mechanic/mechanic_home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1400),
          )
          ..forward()
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  _navigateNext();
                }
              });
            }
          });
  }

  Future<void> _navigateNext() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {
      // Fetch fresh profile from database for persistent active session
      final profileLoaded = await ref
          .read(authProvider.notifier)
          .fetchUserProfile(currentUser.id);

      if (!mounted) return;

      final authState = ref.read(authProvider);

      if (profileLoaded && authState.profile != null) {
        final userProfile = ref.read(currentUserProfileProvider);

        if (userProfile.role == UserRole.mechanic) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MechanicHomeScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    // No active session -> Show Role Selection screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.primaryStrong, scheme.primary],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/icons/icon.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: scheme.onPrimary,
                      alignment: Alignment.center,
                      child: Text(
                        'M',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(color: scheme.primary, fontSize: 28),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'MechX',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: scheme.onPrimary,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CAR BROKEN DOWN? WE ARE ON OUR WAY.',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.75),
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 36),
              AnimatedBuilder(
                animation: _controller,
                builder: (_, _) => GaugeArc(
                  progress: _controller.value,
                  trackColor: scheme.onPrimary.withValues(alpha: 0.2),
                  valueColor: c.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
