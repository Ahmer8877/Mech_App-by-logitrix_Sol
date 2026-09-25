import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cores/providers/auth_provider.dart';
import '../../cores/providers/chat_provider.dart';
import '../../cores/theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String otherUserId;
  final String otherName;

  const ChatScreen({
    super.key,
    this.bookingId = '',
    this.otherUserId = '',
    String? otherName,
    String? mechanicName,
  }) : otherName = otherName ?? mechanicName ?? 'Chat';

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.bookingId.isNotEmpty) {
        final activeUserId = ref.read(authProvider).user?.id;
        if (activeUserId != null) {
          ref.read(activeChatUserBookingKeyProvider.notifier).state =
              '$activeUserId:${widget.bookingId}';
        }
        _markRead();
      }
    });
  }

  void _markRead() {
    if (!mounted) return;
    final activeUserId = ref.read(authProvider).user?.id;
    if (activeUserId != null && widget.bookingId.isNotEmpty) {
      ref
          .read(chatRepositoryProvider)
          .markRead(bookingId: widget.bookingId, activeUserId: activeUserId);
    }
  }

  Future<void> _send() async {
    final userId = ref.read(authProvider).user?.id;
    final message = _controller.text.trim();
    if (userId == null ||
        widget.bookingId.isEmpty ||
        widget.otherUserId.isEmpty ||
        message.isEmpty) {
      return;
    }

    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .send(
            bookingId: widget.bookingId,
            senderId: userId,
            receiverId: widget.otherUserId,
            message: message,
          );
      _controller.clear();
      _markRead();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void deactivate() {
    if (widget.bookingId.isNotEmpty) {
      final activeUserId = ref.read(authProvider).user?.id;
      final chatRepo = ref.read(chatRepositoryProvider);
      final keyNotifier = ref.read(activeChatUserBookingKeyProvider.notifier);

      Future.microtask(() {
        keyNotifier.state = null;
      });

      if (activeUserId != null) {
        chatRepo.markRead(
          bookingId: widget.bookingId,
          activeUserId: activeUserId,
        );
      }
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookingId.isEmpty || widget.otherUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherName)),
        body: const Center(child: Text('Open a booking to start a live chat.')),
      );
    }

    final messages = ref.watch(chatMessagesProvider(widget.bookingId));
    final currentUserId = ref.watch(authProvider).user?.id;

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load chat: $error')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final message = items[index];
                    final isMine = message.senderId == currentUserId;

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primary
                              : context.colors.surface2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message.message,
                          style: TextStyle(
                            color: isMine
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sending ? null : _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
