import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../models/content_record.dart';
import '../services/chat_repository.dart';
import '../services/content_repository.dart';
import '../services/llm_client.dart' as llm;
import '../services/supabase_config.dart';
import '../theme/app_colors.dart';

/// Chat streams replies from the backend's /chat endpoint (SSE), mirroring
/// Archive/Pending's use of the backend for summarization. Session history
/// lives in Supabase's chat_sessions table so it syncs across devices.
class ChatPage extends StatefulWidget {
  final int? initialContentId;
  final int initialRequestSeq;

  const ChatPage({
    super.key,
    this.initialContentId,
    this.initialRequestSeq = 0,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _contentRepo = ContentRepository();
  final _chatRepo = ChatRepository();
  final _draftController = TextEditingController();
  final _scrollController = ScrollController();

  List<ContentRecord>? _articles;
  List<ChatSessionSummary> _sessionSummaries = [];
  int? _selectedId;
  ChatSession? _session;
  String _streamingText = '';
  bool _sending = false;
  String? _error;
  String _provider = 'claude';
  String _backendUrl = 'http://127.0.0.1:3000';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadArticles();
    _refreshSessionList();
    if (widget.initialContentId != null) _openSession(widget.initialContentId!);
  }

  Future<void> _loadSettings() async {
    final config = await SupabaseConfigStore.load();
    if (!mounted) return;
    setState(() => _backendUrl = config.cleanBackendUrl);
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialContentId != null &&
        widget.initialRequestSeq != oldWidget.initialRequestSeq) {
      _openSession(widget.initialContentId!);
    }
  }

  @override
  void dispose() {
    _draftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    try {
      final articles = await _contentRepo.listByStatus('approved');
      if (!mounted) return;
      setState(() => _articles = articles);
    } catch (_) {
      if (!mounted) return;
      setState(() => _articles = []);
    }
  }

  Future<void> _refreshSessionList() async {
    final summaries = await _chatRepo.listSessions();
    if (!mounted) return;
    setState(() => _sessionSummaries = summaries);
  }

  Future<void> _refreshSessionScreen() async {
    await Future.wait([_loadArticles(), _refreshSessionList()]);
  }

  ContentRecord? _findArticle(int id) {
    final articles = _articles;
    if (articles == null) return null;
    for (final a in articles) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> _openSession(int id) async {
    setState(() {
      _selectedId = id;
      _streamingText = '';
      _error = null;
      _draftController.clear();
    });
    final session = await _chatRepo.getSession(id);
    if (!mounted || _selectedId != id) return;
    setState(() {
      _session = session;
      _provider = session.provider ?? 'claude';
    });
  }

  void _closeSession() {
    setState(() {
      _selectedId = null;
      _session = null;
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend() async {
    final text = _draftController.text.trim();
    final id = _selectedId;
    if (text.isEmpty || _sending || id == null) return;
    final article = _findArticle(id);
    if (article == null) return;

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      createdAt: DateTime.now().toIso8601String(),
    );
    setState(() {
      _session = ChatSession(
        messages: [...(_session?.messages ?? []), userMsg],
        provider: _provider,
        updatedAt: userMsg.createdAt,
      );
      _draftController.clear();
      _sending = true;
      _streamingText = '';
      _error = null;
    });
    _scrollToEnd();
    await _chatRepo.appendMessage(id, userMsg);
    await _chatRepo.setProvider(id, _provider);
    _refreshSessionList();

    try {
      final reply = await llm.streamChat(
        backendUrl: _backendUrl,
        articleText: article.data.original ?? '',
        history: _session!.messages,
        onChunk: (chunk) {
          if (!mounted) return;
          setState(() => _streamingText += chunk);
          _scrollToEnd();
        },
      );
      final assistantMsg = ChatMessage(
        role: 'assistant',
        content: reply,
        createdAt: DateTime.now().toIso8601String(),
      );
      await _chatRepo.appendMessage(id, assistantMsg);
      if (!mounted || _selectedId != id) return;
      setState(() {
        _session = ChatSession(
          messages: [..._session!.messages, assistantMsg],
          provider: _provider,
          updatedAt: assistantMsg.createdAt,
        );
        _sending = false;
        _streamingText = '';
      });
      _refreshSessionList();
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _streamingText = '';
        _error = e.toString();
      });
    }
  }

  Future<void> _confirmDeleteSession(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.slate900,
        title: const Text(
          'Delete this conversation?',
          style: TextStyle(color: AppColors.slate100),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.slate400),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.red400),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _chatRepo.deleteSession(id);
    await _refreshSessionList();
    if (_selectedId == id) _closeSession();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedId == null) return _buildSessionList();
    return _buildConversation();
  }

  Widget _buildSessionList() {
    final articles = _articles;
    if (articles == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.indigo500),
      );
    }

    final articleMap = {for (final a in articles) a.id: a};
    final summaryMap = {for (final s in _sessionSummaries) s.contentId: s};
    final ids = summaryMap.keys.where(articleMap.containsKey).toList()
      ..sort((a, b) {
        final ta = summaryMap[a]?.updatedAt;
        final tb = summaryMap[b]?.updatedAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

    if (ids.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshSessionScreen,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            Text(
              'Start a chat by tapping "Chat with this article" in Archive.',
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshSessionScreen,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: ids.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.slate800),
        itemBuilder: (context, i) {
          final id = ids[i];
          final article = articleMap[id]!;
          final summary = summaryMap[id];
          return ListTile(
            onTap: () => _openSession(id),
            leading: article.data.thumbnail != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      article.data.thumbnail!,
                      height: 44,
                      width: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 44,
                        width: 44,
                        color: AppColors.slate800,
                      ),
                    ),
                  )
                : Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
            title: Text(
              article.data.title ?? article.data.category ?? 'Article',
              style: const TextStyle(
                color: AppColors.slate100,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              summary?.lastMessage ?? article.url,
              style: const TextStyle(color: AppColors.slate500, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.slate500,
                size: 20,
              ),
              onPressed: () => _confirmDeleteSession(id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversation() {
    final article = _findArticle(_selectedId!);
    if (article == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.indigo500),
      );
    }
    final messages = _session?.messages ?? [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.indigo500, width: 2),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.slate300),
                onPressed: _closeSession,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.data.title != null)
                      Text(
                        article.data.title!,
                        style: const TextStyle(
                          color: AppColors.slate100,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      article.url,
                      style: const TextStyle(
                        color: AppColors.indigo400,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _openSession(_selectedId!),
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in messages) _MessageBubble(message: m),
                if (_sending)
                  _MessageBubble(
                    message: ChatMessage(
                      role: 'assistant',
                      content: _streamingText.isEmpty ? '...' : _streamingText,
                      createdAt: '',
                    ),
                  ),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.red950.withValues(alpha: 0.4),
                      border: Border.all(color: AppColors.red900),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.red400,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              border: Border.all(color: AppColors.slate700),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _draftController,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(
                      color: AppColors.slate100,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Ask a question about the article...',
                      hintStyle: TextStyle(color: AppColors.slate500),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: _draftController,
                  builder: (context, value, _) {
                    final canSend = value.text.trim().isNotEmpty && !_sending;
                    return TextButton(
                      onPressed: canSend ? _handleSend : null,
                      style: TextButton.styleFrom(
                        backgroundColor: canSend
                            ? AppColors.indigo600
                            : AppColors.slate800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Send',
                        style: TextStyle(
                          color: canSend ? Colors.white : AppColors.slate600,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.indigo600 : AppColors.slate800,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.slate100,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
