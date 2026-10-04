import 'package:flutter/material.dart';
import '../../cores/config/supabase_config.dart';
import '../../cores/repositories/support_repository.dart';
import '../../widgets/app_text.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/step_progress.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _controller = TextEditingController();
  final _repository = const SupportRepository();
  String? _conversationId;
  Stream<List<Map<String, dynamic>>>? _messages;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Please login again.');
      final conversation = await _repository.getOrCreateConversation(userId);
      final id = conversation['id'].toString();
      if (!mounted) return;
      setState(() {
        _conversationId = id;
        _messages = _repository.watchMessages(id);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('Unable to open support chat: $e')),
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final conversationId = _conversationId;
    if (_sending || text.isEmpty || conversationId == null) return;
    setState(() => _sending = true);
    try {
      await _repository.sendMessage(
        conversationId: conversationId,
        message: text,
      );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currentUserId = supabase.auth.currentUser?.id;
    return Scaffold(
      appBar: const FlowAppBar(title: 'MechX Support'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: c.surface2,
                  child: const AppText(
                    'You are chatting directly with MechX Support. Please describe your issue clearly.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _messages,
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? const [];
                      if (messages.isEmpty) {
                        return const Center(child: AppText('No messages yet.'));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final item = messages[index];
                          final mine =
                              item['sender_id']?.toString() == currentUserId;
                          final time = DateTime.tryParse(
                            item['created_at']?.toString() ?? '',
                          )?.toLocal();
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .78,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Theme.of(context).colorScheme.primary
                                    : c.surface2,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Column(
                                crossAxisAlignment: mine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    item['message']?.toString() ?? '',
                                    style: TextStyle(
                                      color: mine
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : null,
                                    ),
                                  ),
                                  if (time != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: mine
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                    .withValues(alpha: .7)
                                              : c.textMuted,
                                        ),
                                      ),
                                    ),
                                ],
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
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Type your issue...',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
