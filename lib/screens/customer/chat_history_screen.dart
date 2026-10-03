import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/chat_provider.dart';
import '../../cores/theme/app_theme.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider.select((s) => s.user?.id));
    final refreshTick = ref.watch(chatHistoryRefreshProvider);
    if (userId == null) {
      return const Center(
        child: AppText('Please sign in to view chat history.'),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(chatRepositoryProvider).getHistoryForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: AppText('Unable to load chat history: ${snapshot.error}'),
          );
        }
        final history = snapshot.data ?? const [];
        if (history.isEmpty) {
          return const Center(
            child: AppText('No completed conversations yet.'),
          );
        }

        return SafeArea(
          top: true,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.read(chatHistoryRefreshProvider.notifier).state =
                  refreshTick + 1;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = history[index];
                final otherName = item['other_name']?.toString() ?? 'User';
                final initial = otherName.trim().isEmpty
                    ? 'U'
                    : otherName.trim()[0].toUpperCase();
                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          bookingId: item['booking_id'].toString(),
                          otherUserId: item['other_user_id'].toString(),
                          otherName: otherName,
                          readOnly: true,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(radius: 22, child: AppText(initial)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppText(
                                  otherName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AppText(
                                  item['service_title']?.toString() ??
                                      'Service',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                AppText(
                                  item['last_message']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

final chatHistoryRefreshProvider = StateProvider<int>((ref) => 0);
