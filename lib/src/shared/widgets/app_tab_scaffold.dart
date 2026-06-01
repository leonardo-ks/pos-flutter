import 'package:flutter/material.dart';

class AppTabItem {
  const AppTabItem({required this.label, required this.child});

  final String label;
  final Widget child;
}

class AppTabScaffold extends StatelessWidget {
  const AppTabScaffold({
    super.key,
    required this.tabs,
    required this.emptyMessage,
    this.isScrollable = true,
  });

  final List<AppTabItem> tabs;
  final String emptyMessage;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: isScrollable,
            tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
            tabs: [for (final tab in tabs) Tab(text: tab.label)],
          ),
          Expanded(
            child: TabBarView(children: [for (final tab in tabs) tab.child]),
          ),
        ],
      ),
    );
  }
}
