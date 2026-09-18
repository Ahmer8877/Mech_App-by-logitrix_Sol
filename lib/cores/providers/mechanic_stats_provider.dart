import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import 'auth_provider.dart';

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

/// Live dashboard data. A single bookings realtime stream drives both
/// mechanic jobs and unassigned customer requests, so the home screen does
/// not need a manual reload after a new request or job-status change.
final mechanicStatsProvider =
StreamProvider.autoDispose<MechanicDashboardStats>((ref) {
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) {
    return Stream.value(MechanicDashboardStats.empty);
  }

  final stream = supabase
      .from('bookings')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  return stream.map((rows) {
    final jobs = rows
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['mechanic_id']?.toString() == userId)
        .toList();

    final pendingRows = rows
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) =>
    row['mechanic_id'] == null && row['status']?.toString() == 'pending')
        .toList();

    double priceOf(Map<String, dynamic> row) {
      final value = row['agreed_price'] ?? row['budget_price'];
      return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    }

    DateTime? dateOf(Map<String, dynamic> row) {
      return DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.tryParse(row['created_at']?.toString() ?? '');
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart =
    todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    double earningsSince(DateTime start) {
      return jobs
          .where((row) => row['status']?.toString() == 'completed')
          .where((row) {
        final date = dateOf(row);
        return date != null && !date.isBefore(start);
      })
          .fold<double>(0, (sum, row) => sum + priceOf(row));
    }

    final completed = jobs
        .where((row) => row['status']?.toString() == 'completed')
        .length;
    final ongoing = jobs
        .where((row) => const {'accepted', 'on_the_way', 'in_progress'}
        .contains(row['status']?.toString()))
        .length;
    final request = pendingRows.isEmpty ? null : pendingRows.first;

    return MechanicDashboardStats(
      todayEarnings: earningsSince(todayStart),
      weekEarnings: earningsSince(weekStart),
      monthEarnings: earningsSince(monthStart),
      totalEarnings: earningsSince(DateTime.fromMillisecondsSinceEpoch(0)),
      completedJobs: completed,
      ongoingJobs: ongoing,
      pendingRequests: pendingRows.length,
      totalCompletedJobs: completed,
      recentRequestId: request?['id']?.toString(),
      recentRequestService: request?['service_title']?.toString(),
      recentRequestAddress: request?['pickup_address']?.toString(),
      recentRequestBudget: request?['budget_price'] is num
          ? (request?['budget_price'] as num).toDouble()
          : double.tryParse('${request?['budget_price'] ?? ''}'),
    );
  });
});
