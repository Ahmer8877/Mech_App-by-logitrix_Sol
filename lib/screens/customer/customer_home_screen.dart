import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/services_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_atoms.dart';
import '../../widgets/app_buttons.dart';
import '../../cores/models/user_role.dart';
import '../notification/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'select_vehicle_screen.dart';
import 'booking_history_screen.dart';
import 'chat_screen.dart';
import 'all_services_screen.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  int _navIndex = 0;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else if (hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  Widget _buildHomeContent(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    final userProfile = ref.watch(currentUserProfileProvider);
    final servicesAsync = ref.watch(servicesProvider);
    final popularServices =
        servicesAsync.valueOrNull?.take(6).toList() ?? const [];

    final firstName = userProfile.fullName.trim().split(' ').first;
    final greeting = _getGreeting();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, $firstName 👋',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 17),
                      ),
                      Text(
                        '📍 Choose pickup location when creating a request',
                        style: TextStyle(fontSize: 11, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    NotificationIconButton(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _navIndex = 3),
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: c.surface2,
                        backgroundImage:
                            userProfile.avatarUrl != null &&
                                userProfile.avatarUrl!.isNotEmpty
                            ? NetworkImage(userProfile.avatarUrl!)
                                  as ImageProvider
                            : null,
                        child:
                            (userProfile.avatarUrl == null ||
                                userProfile.avatarUrl!.isEmpty)
                            ? Text(
                                userProfile.initials,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: c.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'What service do you need?',
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, c.primaryStrong],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need a mechanic right now?',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get matched in under 2 minutes',
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.8),
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 150,
                    child: AccentButton(
                      label: 'Request Now',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SelectVehicleScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Popular Services',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AllServicesScreen(),
                    ),
                  ),
                  child: Text(
                    'View all',
                    style: TextStyle(fontSize: 10.5, color: scheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (servicesAsync.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (servicesAsync.hasError)
              Row(
                children: [
                  Text(
                    'Services unavailable',
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ref.invalidate(servicesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.05,
                children: popularServices
                    .map(
                      (s) => ServiceTile(
                        icon: s.icon,
                        label: s.title,
                        onTap: null, // Static display tile
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      RepaintBoundary(child: _buildHomeContent(context, ref)),
      const RepaintBoundary(child: BookingHistoryScreen()),
      const RepaintBoundary(child: ChatScreen()),
      const RepaintBoundary(child: ProfileScreen(role: UserRole.customer)),
    ];

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
