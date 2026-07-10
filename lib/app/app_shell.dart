import 'package:flutter/material.dart';

import '../features/ask/ask_page.dart';
import '../features/compare/compare_page.dart';
import '../features/news/news_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = <String>['समाचार', 'तुलना', 'सोधपुछ'];

  static const _pages = <Widget>[
    NewsPage(),
    ComparePage(),
    AskPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.newspaper), label: 'समाचार'),
          NavigationDestination(
            icon: Icon(Icons.compare_arrows),
            label: 'तुलना',
          ),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'सोधपुछ'),
        ],
      ),
    );
  }
}
