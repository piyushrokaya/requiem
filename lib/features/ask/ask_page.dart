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
    return Column(
      children: [
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      dummyAskFallback,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Align(
                      alignment: item.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        color: item.isUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(item.text),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'प्रश्न सोध्नुहोस्…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _send,
                child: const Text('Send'),
              ),
            ],
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

class _ChatItem {
  _ChatItem({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}
