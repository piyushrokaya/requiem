import 'package:flutter/material.dart';

import '../../core/services/qna_repository.dart';

const String _emptyHint =
    'समाचारबारे प्रश्न सोध्नुहोस् — म डेटाबेसमा भएका समाचारका आधारमा उत्तर दिन्छु।';

const String _errorText =
    'माफ गर्नुहोस्, अहिले जवाफ दिन सकिनँ। कृपया फेरि प्रयास गर्नुहोस्।';

class AskPage extends StatefulWidget {
  const AskPage({super.key});

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  final TextEditingController _controller = TextEditingController();
  final QnaRepository _repo = QnaRepository();
  final List<_ChatItem> _items = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 30,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _emptyHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return _ChatBubble(item: _items[index]);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_sending,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'प्रश्न सोध्नुहोस्…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _sending ? scheme.surfaceContainerHighest : scheme.primary,
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : Icon(Icons.arrow_upward, color: scheme.onPrimary),
                    tooltip: 'Send',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _sending) return;

    _controller.clear();
    setState(() {
      _items.add(_ChatItem(isUser: true, text: q));
      _items.add(const _ChatItem(isUser: false, text: '', isLoading: true));
      _sending = true;
    });

    try {
      final result = await _repo.ask(q);
      if (!mounted) return;
      setState(() {
        _items[_items.length - 1] = _ChatItem(
          isUser: false,
          text: result.answer.isEmpty ? _errorText : result.answer,
          sources: result.sources,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items[_items.length - 1] =
            const _ChatItem(isUser: false, text: _errorText);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.item});

  final _ChatItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = item.isUser;

    final Widget bubbleChild = item.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.onSurfaceVariant,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isUser ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
              if (!isUser && item.sources.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'स्रोत: ${item.sources.join(', ')}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
      ),
      child: bubbleChild,
    );

    final avatar = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isUser ? scheme.secondaryContainer : scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUser ? Icons.person_outline : Icons.smart_toy_outlined,
        size: 16,
        color: isUser ? scheme.onSecondaryContainer : scheme.onPrimaryContainer,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isUser
            ? [bubble, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), bubble],
      ),
    );
  }
}

class _ChatItem {
  const _ChatItem({
    required this.isUser,
    required this.text,
    this.isLoading = false,
    this.sources = const [],
  });

  final bool isUser;
  final String text;
  final bool isLoading;
  final List<String> sources;
}
