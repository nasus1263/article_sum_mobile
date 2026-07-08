import 'package:flutter/material.dart';

import 'pages/archive_page.dart';
import 'pages/chat_page.dart';
import 'pages/pending_page.dart';
import 'pages/settings_page.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const ArticleSummaryApp());
}

class ArticleSummaryApp extends StatelessWidget {
  const ArticleSummaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clip Brief',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.slate950,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.indigo600,
          secondary: AppColors.indigo500,
          surface: AppColors.slate900,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.slate950,
          foregroundColor: AppColors.slate100,
          elevation: 0,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: AppColors.slate100,
              displayColor: AppColors.slate100,
            ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    PendingPage(),
    ArchivePage(),
    ChatPage(),
    SettingsPage(),
  ];

  static const _titles = ['Pending Approval', 'Archive', 'Chat', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: SafeArea(child: IndexedStack(index: _index, children: _pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.slate900,
        indicatorColor: AppColors.indigo600,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.hourglass_empty), label: 'Pending'),
          NavigationDestination(icon: Icon(Icons.archive_outlined), label: 'Archive'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
