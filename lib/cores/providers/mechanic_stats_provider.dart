import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import 'auth_provider.dart';

/// Data class holding mechanic dashboard performance statistics and metrics.
/// Computes today, week, month, and lifetime earnings from completed Supabase bookings.
/// Also tracks counters for completed jobs, ongoing jobs, and pending service requests.
class MechanicDashboardStats {
  final double todayEarnings;
  final double weekEarnings;
  final double monthEarnings;
  final double totalEarnings;
  final int completedJobs;
  final int ongoingJobs;
  final int pendingRequests;
  final int totalCompletedJobs;
  final String? recentRequestId;
  final String? recentRequestService;
  final String? recentRequestAddress;
  final double? recentRequestBudget;

  const MechanicDashboardStats({
    required this.todayEarnings,
    required this.weekEarnings,
    required this.monthEarnings,
    required this.totalEarnings,
    required this.completedJobs,
    required this.ongoingJobs,
    required this.pendingRequests,
    required this.totalCompletedJobs,
    this.recentRequestId,
    this.recentRequestService,
    this.recentRequestAddress,
    this.recentRequestBudget,
  });

  static const empty = MechanicDashboardStats(
    todayEarnings: 0,
    weekEarnings: 0,
    monthEarnings: 0,
    totalEarnings: 0,
    completedJobs: 0,
    ongoingJobs: 0,
    pendingRequests: 0,
    totalCompletedJobs: 0,
  );
}

/// Helper function querying Supabase database for mechanic booking statistics.
/// Sums completed job payments for today, this week, this month, and all-time.
/// Returns a MechanicDashboardStats instance with calculated financial and job metrics.
Future<MechanicDashboardStats> _loadMechanicStats(String userId) async {
  final rows = await supabase
      .from('bookings')
      .select(
        'id, mechanic_id, status, budget_price, agreed_price, created_at, updated_at, completed_at',
      )
      .eq('mechanic_id', userId)
      .order('created_at', ascending: false);

  final jobs = (rows as List)
      .map((row) => Map<String, dynamic>.from(row))
      .toList();

  double priceOf(Map<String, dynamic> row) {
    final agreed = row['agreed_price'];
    final agreedValue = agreed is num
        ? agreed.toDouble()
        : double.tryParse(agreed?.toString() ?? '');
    if (agreedValue != null && agreedValue > 0) return agreedValue;

    final budget = row['budget_price'];
    final budgetValue = budget is num
        ? budget.toDouble()
        : double.tryParse(budget?.toString() ?? '');
    return budgetValue ?? 0.0;
  }

  DateTime? completionDateOf(Map<String, dynamic> row) {
    final completed = DateTime.tryParse(row['completed_at']?.toString() ?? '');
    if (completed != null) return completed;
    return DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
        DateTime.tryParse(row['created_at']?.toString() ?? '');
  }

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);

  double earningsSince(DateTime start) {
    return jobs
        .where((row) => row['status']?.toString() == 'completed')
        .where((row) {
          final date = completionDateOf(row);
          return date != null && !date.isBefore(start);
        })
        .fold<double>(0, (sum, row) => sum + priceOf(row));
  }

  final completed = jobs
      .where((row) => row['status']?.toString() == 'completed')
      .length;
  final ongoing = jobs
      .where(
        (row) => const {
          'accepted',
          'on_the_way',
          'in_progress',
        }.contains(row['status']?.toString()),
      )
      .length;

  return MechanicDashboardStats(
    todayEarnings: earningsSince(todayStart),
    weekEarnings: earningsSince(weekStart),
    monthEarnings: earningsSince(monthStart),
    totalEarnings: earningsSince(DateTime.fromMillisecondsSinceEpoch(0)),
    completedJobs: completed,
    ongoingJobs: ongoing,
    pendingRequests: 0,
    totalCompletedJobs: completed,
  );
}

/// Auto-disposing StreamProvider supplying live dashboard statistics for the logged-in mechanic.
/// Performs an immediate database query on app start so earnings load instantly after cold restarts.
/// Listens to real-time 'bookings' table stream updates to refresh stats when jobs complete or change.
final mechanicStatsProvider =
    StreamProvider.autoDispose<MechanicDashboardStats>((ref) async* {
      final userId =
          ref.watch(authProvider.select((state) => state.user?.id)) ??
          supabase.auth.currentUser?.id;

      if (userId == null) {
        yield MechanicDashboardStats.empty;
        return;
      }

      yield await _loadMechanicStats(userId);

      try {
        await for (final _
            in supabase
                .from('bookings')
                .stream(primaryKey: ['id'])
                .eq('mechanic_id', userId)) {
          yield await _loadMechanicStats(userId);
        }
      } catch (_) {}
    });
