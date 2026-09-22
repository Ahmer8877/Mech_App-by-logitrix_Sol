import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/models/user_role.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/providers/mechanic_stats_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_atoms.dart';
import '../../widgets/app_buttons.dart';
import '../notification/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'earnings_screen.dart';
import 'mechanic_bookings_screen.dart';
import 'new_request_screen.dart';
import 'request_details_screen.dart';
import 'send_offer_screen.dart';

class MechanicHomeScreen extends ConsumerStatefulWidget {
  const MechanicHomeScreen({super.key});

  @override
  ConsumerState<MechanicHomeScreen> createState() => _MechanicHomeScreenState();
}

class _MechanicHomeScreenState extends ConsumerState<MechanicHomeScreen> {
  bool _online = true;
  int _navIndex = 0;

  Widget _buildHomeContent(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    final userProfile = ref.watch(currentUserProfileProvider);
    final statsAsync = ref.watch(mechanicStatsProvider);
    final stats = statsAsync.valueOrNull ?? MechanicDashboardStats.empty;

    final openRequestsAsync = ref.watch(openRequestsProvider);
    final openRequests = openRequestsAsync.valueOrNull ?? [];
    final recentRequest = openRequests.isNotEmpty ? openRequests.first : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are Online',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 16),
                    ),
                    Text(
                      _online ? '● Accepting requests' : '● Offline',
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                  ],
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
                    Switch(
                      value: _online,
                      onChanged: (v) => setState(() => _online = v),
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
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const EarningsScreen())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, c.primaryStrong],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      "TOTAL EARNINGS",
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.75),
                        fontSize: 9.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PKR ${stats.totalEarnings.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: scheme.onPrimary, fontSize: 22),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${stats.completedJobs} Jobs Completed',
                          style: TextStyle(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${stats.ongoingJobs} Ongoing',
                          style: TextStyle(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatMini(
                    value: '${stats.completedJobs}',
                    label: 'Completed',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatMini(
                    value: '${openRequests.length}',
                    label: 'Pending',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatMini(
                    value: userProfile.rating.toStringAsFixed(1),
                    label: 'Rating',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Requests',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => setState(() => _navIndex = 1),
                  child: Text(
                    'View all',
                    style: TextStyle(fontSize: 10.5, color: scheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (openRequestsAsync.isLoading && recentRequest == null)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Searching for new requests...',
                        style: TextStyle(fontSize: 11.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else if (recentRequest == null)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Searching for new requests...',
                        style: TextStyle(fontSize: 11.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '⚙️ ${recentRequest['service_title'] ?? 'Service Request'}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (recentRequest['budget_price'] != null)
                          Text(
                            'PKR ${((recentRequest['budget_price'] as num?) ?? 0).toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 9.5, color: c.textMuted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recentRequest['pickup_address']?.toString() ?? 'Location unavailable',
                      style: TextStyle(fontSize: 9.5, color: c.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlineActionButton(
                            label: 'View Details',
                            onPressed: () {
                              final id = recentRequest['id']?.toString();
                              if (id != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RequestDetailsScreen(bookingId: id),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AccentButton(
                            label: 'Send Offer',
                            onPressed: () {
                              final id = recentRequest['id']?.toString();
                              if (id != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SendOfferScreen(bookingId: id),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
      const RepaintBoundary(child: NewRequestScreen()),
      const RepaintBoundary(child: MechanicBookingsScreen()),
      const RepaintBoundary(child: ProfileScreen(role: UserRole.mechanic)),
    ];

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Bookings',
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
