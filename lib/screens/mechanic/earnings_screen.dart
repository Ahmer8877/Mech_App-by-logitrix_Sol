import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/mechanic_stats_provider.dart';
import '../../cores/theme/app_theme.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(mechanicStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const AppText('Earnings')),
      body: a.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            (Center(child: AppText('Failed to load earnings: $e'))),
        data: (s) => Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'PKR ${s.totalEarnings.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              AppText(
                'Total Lifetime Earnings',
                style: TextStyle(color: context.colors.textMuted),
              ),
              const SizedBox(height: 20),
              _Row(
                "Today's Earnings",
                'PKR ${s.todayEarnings.toStringAsFixed(0)}',
              ),
              _Row('This Week', 'PKR ${s.weekEarnings.toStringAsFixed(0)}'),
              _Row('This Month', 'PKR ${s.monthEarnings.toStringAsFixed(0)}'),
              _Row('Total Jobs Completed', s.totalCompletedJobs.toString()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String l, v;
  const _Row(this.l, this.v);
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(l),
        AppText(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
