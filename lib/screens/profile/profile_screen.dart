import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/models/user_role.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/language_provider.dart';
import '../../cores/providers/theme_provider.dart';
import '../../cores/providers/vehicles_provider.dart';
import '../../cores/providers/bookings_provider.dart';
import '../../cores/providers/mechanic_stats_provider.dart';
import '../../cores/providers/customer_rating_provider.dart';
import '../../cores/providers/mechanic_rating_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_atoms.dart';
import '../auth&role/role_select_screen.dart';
import '../customer/my_vehicles_screen.dart';
import '../hepl&support/help_support_screen.dart';
import '../mechanic/verification_documents_screen.dart';
import '../notification/notifications_screen.dart';
import '../saved_payment_method/saved_payment_methods_screen.dart';
import 'edit_profile_screen.dart';

/// Shared Profile screen — displays dynamic profile image and data from [currentUserProfileProvider].
String _ratingText(double? liveRating, {double fallback = 0.0}) {
  final value = (liveRating != null && liveRating > 0) ? liveRating : fallback;
  return value > 0 ? value.toStringAsFixed(1) : '0.0';
}

class ProfileScreen extends ConsumerWidget {
  final UserRole role;
  const ProfileScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    final userProfile = ref.watch(currentUserProfileProvider);
    final isMechanic = userProfile.role == UserRole.mechanic;
    final currentThemeMode = ref.watch(themeModeProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final bookingsAsync = ref.watch(bookingsProvider);
    final customerBookings = bookingsAsync.valueOrNull ?? const [];
    final customerRatingAsync = isMechanic
        ? null
        : ref.watch(customerRatingProvider);
    final mechanicStatsAsync = isMechanic
        ? ref.watch(mechanicStatsProvider)
        : null;
    final mechanicRatingAsync = isMechanic
        ? ref.watch(mechanicRatingProvider(userProfile.id))
        : null;
    final mechanicStats =
        mechanicStatsAsync?.valueOrNull ?? MechanicDashboardStats.empty;

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Profile', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: c.surface2,
                backgroundImage:
                    userProfile.avatarUrl != null &&
                        userProfile.avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(userProfile.avatarUrl!)
                          as ImageProvider
                    : null,
                child:
                    (userProfile.avatarUrl == null ||
                        userProfile.avatarUrl!.isEmpty)
                    ? AppText(
                        userProfile.initials,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      userProfile.fullName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SelectableText(
                      userProfile.email.isNotEmpty
                          ? userProfile.email
                          : 'No email',
                      textDirection: TextDirection.ltr,
                      maxLines: 2,
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                    if (isMechanic) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.star, size: 12, color: c.accent),
                          const SizedBox(width: 3),
                          AppText(
                            '${mechanicRatingAsync?.when(data: (val) => val.toStringAsFixed(1), loading: () => mechanicRatingAsync.valueOrNull?.toStringAsFixed(1) ?? userProfile.rating.toStringAsFixed(1), error: (_, _) => mechanicRatingAsync.valueOrNull?.toStringAsFixed(1) ?? userProfile.rating.toStringAsFixed(1)) ?? userProfile.rating.toStringAsFixed(1)} · ${userProfile.totalJobs} jobs',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isMechanic)
            Row(
              children: [
                Expanded(
                  child: StatMini(
                    value:
                        'PKR ${mechanicStats.todayEarnings.toStringAsFixed(0)}',
                    label: 'Today',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatMini(
                    value: '${mechanicStats.totalCompletedJobs}',
                    label: 'Total Jobs',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isMechanic
                      ? _MechanicRatingStat(
                          value: userProfile.rating,
                          label: 'Rating',
                        )
                      : StatMini(
                          value: _ratingText(
                            customerRatingAsync?.valueOrNull,
                            fallback: userProfile.rating,
                          ),
                          label: 'Rating',
                        ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: StatMini(
                    value: bookingsAsync.isLoading
                        ? '…'
                        : '${customerBookings.length}',
                    label: 'Bookings',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatMini(
                    value: vehiclesAsync.isLoading
                        ? '…'
                        : '${vehiclesAsync.valueOrNull?.length ?? 0}',
                    label: 'Vehicles',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingStat(
                    value:
                        customerRatingAsync?.valueOrNull ?? userProfile.rating,
                    label: 'Given Rating',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),

          _MenuTile(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EditProfileScreen(role: role)),
            ),
          ),
          if (isMechanic)
            _MenuTile(
              icon: Icons.verified_outlined,
              label: 'Verification Documents',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VerificationDocumentsScreen(),
                ),
              ),
            )
          else
            _MenuTile(
              icon: Icons.directions_car_outlined,
              label: 'My Vehicles',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyVehiclesScreen()),
              ),
            ),
          _MenuTile(
            icon: Icons.payments_outlined,
            label: 'Payment Methods',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SavedPaymentMethodsScreen(),
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.language_outlined,
            label: 'Change Language',
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (sheetContext) {
                final current = ref.read(languageProvider).languageCode;
                return SafeArea(
                  child: RadioGroup<String>(
                    groupValue: current,
                    onChanged: (value) {
                      if (value == null) return;
                      ref.read(languageProvider.notifier).setLanguage(value);
                      Navigator.pop(sheetContext);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ListTile(title: AppText('Change Language')),
                        const RadioListTile<String>(
                          value: 'en',
                          title: AppText('English'),
                        ),
                        const RadioListTile<String>(
                          value: 'ur',
                          title: AppText('Urdu'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _MenuTile(
            icon: Icons.support_agent_outlined,
            label: 'Help & Support',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            ),
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: c.borderStrong.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const AppText(
                'Dark Mode',
                style: TextStyle(fontSize: 12.5),
              ),
              value: currentThemeMode == ThemeMode.dark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggleTheme(),
            ),
          ),
          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                (route) => false,
              );
            },
            icon: Icon(Icons.logout, size: 16, color: c.danger),
            label: AppText('Logout', style: TextStyle(color: c.danger)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              side: BorderSide(color: c.danger.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16),
      ),
      title: AppText(label, style: const TextStyle(fontSize: 12.5)),
      trailing: Icon(Icons.chevron_right, color: c.textMuted, size: 18),
    );
  }
}

class _MechanicRatingStat extends StatelessWidget {
  final double value;
  final String label;
  const _MechanicRatingStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    final display = value > 0 ? value.toStringAsFixed(1) : '0.0';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.borderStrong.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              display,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 8, color: c.textMuted)),
        ],
      ),
    );
  }
}

class _RatingStat extends StatelessWidget {
  final double value;
  final String label;

  const _RatingStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    final display = value > 0 ? value.toStringAsFixed(1) : '0.0';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.borderStrong.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            display,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 8, color: c.textMuted)),
        ],
      ),
    );
  }
}
