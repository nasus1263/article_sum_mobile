import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/archive_page.dart';
import 'pages/chat_page.dart';
import 'pages/login_page.dart';
import 'pages/pending_page.dart';
import 'pages/settings_page.dart';
import 'services/auth_service.dart';
import 'services/clipboard_background.dart';
import 'services/clipboard_watcher.dart';
import 'services/supabase_client_provider.dart';
import 'theme/app_colors.dart';

/// Must match ClipboardAccessibilityService.CALLBACK_HANDLE_KEY (without the
/// "flutter." prefix the shared_preferences plugin adds on Android).
const _kClipboardCallbackHandleKey = 'clipboard_callback_handle';

void main() {
  _registerClipboardCallbackHandle();
  _debugResetActiveFolder();
  runApp(const ArticleSummaryApp());
}

/// Debug-only: clears any stale 'active_folder' pref (e.g. from before
/// folders were switched to kDefaultFolders) so PendingPage's dropdown
/// never starts with a value outside kDefaultFolders and crashes.
Future<void> _debugResetActiveFolder() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('active_folder');
}

/// The callback handle can change between builds, so it's re-registered on
/// every app start for ClipboardAccessibilityService to look up later.
Future<void> _registerClipboardCallbackHandle() async {
  final handle = PluginUtilities.getCallbackHandle(clipboardCallbackDispatcher);
  if (handle == null) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kClipboardCallbackHandleKey, handle.toRawHandle());
}

class ArticleSummaryApp extends StatelessWidget {
  const ArticleSummaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clip Brief',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: AppColors.slate950,
        colorScheme: const ColorScheme.light(
          primary: AppColors.indigo600,
          secondary: AppColors.indigo500,
          surface: AppColors.slate900,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.slate950,
          foregroundColor: AppColors.slate100,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'serif',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.slate100,
          ),
        ),
        textTheme: ThemeData.light().textTheme.apply(
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  AppUser? _user;
  bool _authLoading = true;
  StreamSubscription<AuthState>? _authSub;
  final _clipboardWatcher = ClipboardWatcher();

  static const _titles = ['Categories', 'Pending Approval', 'Archive', 'Favorites', 'Settings'];
  static const _settingsIndex = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clipboardWatcher.primeBaseline();
    _initAuth();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _user != null) {
      _clipboardWatcher.checkOnResume();
    }
  }

  Future<void> _initAuth() async {
    try {
      final client = await SupabaseClientProvider.getClient();
      if (!mounted) return;
      setState(() {
        _user = AppUser.fromSupabaseUser(client.auth.currentUser);
        _authLoading = false;
      });
      _authSub = client.auth.onAuthStateChange.listen((state) {
        if (!mounted) return;
        setState(() => _user = AppUser.fromSupabaseUser(state.session?.user));
      });
    } catch (_) {
      // Supabase not configured yet — Settings stays reachable to fix that.
      if (!mounted) return;
      setState(() => _authLoading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  void _openChatWithArticle(int contentId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          initialContentId: contentId,
          initialRequestSeq: 1,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ArchivePage(onChatWithArticle: _openChatWithArticle, variant: ArchiveVariant.categories),
      const PendingPage(),
      ArchivePage(onChatWithArticle: _openChatWithArticle, variant: ArchiveVariant.archive),
      ArchivePage(onChatWithArticle: _openChatWithArticle, variant: ArchiveVariant.favorites),
      const SettingsPage(),
    ];

    final locked = !_authLoading && _user == null && _index != _settingsIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_user != null)
            TextButton(
              onPressed: _signOut,
              child: Text(
                'Sign out (${_user!.email})',
                style: const TextStyle(color: AppColors.slate400, fontSize: 12),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _authLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.indigo500),
              )
            : locked
            ? const LoginPage()
            : IndexedStack(index: _index, children: pages),
      ),
      floatingActionButton: _index != _settingsIndex && _user != null
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChatPage(),
                  ),
                );
              },
              backgroundColor: AppColors.indigo600,
              foregroundColor: Colors.white,
              child: const Icon(Icons.chat_bubble_outline),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.slate900,
        indicatorColor: AppColors.indigo600,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.hourglass_empty),
            label: 'Pending',
          ),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            label: 'Archive',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
