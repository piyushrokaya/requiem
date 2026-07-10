import 'package:flutter/material.dart';

import '../../core/data/dummy_data.dart';

class AskPage extends StatefulWidget {
  const AskPage({super.key});

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatItem> _items = [];

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
                          dummyAskFallback,
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
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'प्रश्न सोध्नुहोस्…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: scheme.primary,
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: _send,
                    icon: Icon(Icons.arrow_upward, color: scheme.onPrimary),
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

  void _send() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    final lower = q.toLowerCase();
    final match = dummyAskResponses.entries.firstWhere(
      (e) => lower.contains(e.key),
      orElse: () => const MapEntry('', dummyAskFallback),
    );

    setState(() {
      _items.add(_ChatItem(isUser: true, text: q));
      _items.add(_ChatItem(isUser: false, text: match.value));
    });
    _controller.clear();
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.item});

  final _ChatItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = item.isUser;

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
      child: Text(
        item.text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: isUser ? scheme.onPrimary : scheme.onSurface,
        ),
      ),
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
  _ChatItem({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}
