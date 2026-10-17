import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/models/user_profile_model.dart';
import '../../cores/models/user_role.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import 'login_screen.dart';

class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.errorMessage != null &&
          authState.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(authState.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(selectedRoleProvider);

    ref.listen<AppAuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage!.isNotEmpty &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Who are you?',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 21),
              ),
              const SizedBox(height: 4),
              AppText(
                'Select your role to customize your experience',
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
              const SizedBox(height: 22),
              _RoleCard(
                emoji: '🧑',
                title: 'I am a Customer',
                subtitle: 'Book a mechanic for your vehicle',
                selected: selectedRole == UserRole.customer,
                onTap: () {
                  ref.read(selectedRoleProvider.notifier).state =
                      UserRole.customer;
                  ref
                      .read(authProvider.notifier)
                      .setTargetRole(UserRole.customer);
                },
              ),
              const SizedBox(height: 10),
              _RoleCard(
                emoji: '🔧',
                title: 'I am a Mechanic',
                subtitle: 'Earn by providing repair services',
                selected: selectedRole == UserRole.mechanic,
                onTap: () {
                  ref.read(selectedRoleProvider.notifier).state =
                      UserRole.mechanic;
                  ref
                      .read(authProvider.notifier)
                      .setTargetRole(UserRole.mechanic);
                },
              ),
              const Spacer(),
              AccentButton(
                label: 'Continue →',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(role: selectedRole),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.08)
              : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : c.borderStrong,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: AppText(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppText(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: c.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
