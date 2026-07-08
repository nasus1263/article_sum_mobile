import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_record.dart';
import '../services/content_repository.dart';
import '../services/supabase_config.dart';
import '../theme/app_colors.dart';
import '../widgets/content_card.dart';
import '../widgets/full_text_dialog.dart';

class ArchivePage extends StatefulWidget {
  final ValueChanged<int> onChatWithArticle;

  const ArchivePage({super.key, required this.onChatWithArticle});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final _repo = ContentRepository();
  List<ContentRecord>? _records;
  String? _error;
  final _searchController = TextEditingController();
  String _search = '';
  final Set<String> _categoryFilter = {};
  final Set<int> _expanded = {};
  final Map<int, List<ContentRecord>> _relatedMap = {};
  String _backendUrl = 'http://127.0.0.1:3000';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refresh();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text);
    });
  }

  Future<void> _loadSettings() async {
    final config = await SupabaseConfigStore.load();
    if (!mounted) return;
    setState(() {
      _backendUrl = config.backendUrl;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      final records = await _repo.listByStatus('approved');
      if (!mounted) return;
      setState(() => _records = records);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _toggleExpanded(int id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
        _fetchRelatedIfNeeded(id);
      }
    });
  }

  Future<void> _fetchRelatedIfNeeded(int id) async {
    if (_relatedMap.containsKey(id)) return;
    try {
      final related = await _repo.getRelated(id);
      if (!mounted) return;
      setState(() {
        _relatedMap[id] = related;
      });
    } catch (_) {
      // Ignore errors fetching related articles gracefully
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_categoryFilter.contains(category)) {
        _categoryFilter.remove(category);
      } else {
        _categoryFilter.add(category);
      }
    });
  }

  Future<void> _handleDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.slate900,
        title: const Text('Delete this item?', style: TextStyle(color: AppColors.slate100)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red400)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.discard(id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _handleViewOnWeb(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening link: $e')),
      );
    }
  }

  Future<void> _handleRegenerate(int id) async {
    try {
      await _repo.regenerateSummary(id, _backendUrl);
      await _refresh();
    } catch (e) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regeneration failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(_error!, style: const TextStyle(color: AppColors.slate400, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    final records = _records;
    if (records == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.indigo500));
    }

    final categories = <String>{};
    for (final r in records) {
      if (r.data.category != null) categories.add(r.data.category!);
    }
    final sortedCategories = categories.toList()..sort();

    final query = _search.trim().toLowerCase();
    final filtered = records.where((r) {
      if (_categoryFilter.isNotEmpty &&
          !(r.data.category != null && _categoryFilter.contains(r.data.category))) {
        return false;
      }
      if (query.isEmpty) return true;
      final summary = r.data.firstSummary?.toLowerCase() ?? '';
      return r.url.toLowerCase().contains(query) || summary.contains(query);
    }).toList();

    final groups = <String, List<ContentRecord>>{};
    for (final r in filtered) {
      final folder = r.data.folder ?? 'No folder';
      groups.putIfAbsent(folder, () => []).add(r);
    }
    final folders = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'No folder') return 1;
        if (b == 'No folder') return -1;
        return a.compareTo(b);
      });

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.slate100, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Search by URL or summary',
              hintStyle: TextStyle(color: AppColors.slate500),
              filled: true,
              fillColor: AppColors.slate900,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.slate700),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.slate700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.indigo500),
              ),
            ),
          ),
          if (sortedCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedCategories
                  .map((c) => Pill(
                        label: c,
                        active: _categoryFilter.contains(c),
                        onTap: () => _toggleCategory(c),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          if (records.isEmpty)
            const Text('No archived items.', style: TextStyle(color: AppColors.slate500, fontSize: 13)),
          if (records.isNotEmpty && filtered.isEmpty)
            const Text('No items match your search/filter.',
                style: TextStyle(color: AppColors.slate500, fontSize: 13)),
          for (final folder in folders) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                folder,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate400),
              ),
            ),
            for (final r in groups[folder]!) ...[
              _ArchiveCard(
                record: r,
                isExpanded: _expanded.contains(r.id),
                onToggleExpanded: () => _toggleExpanded(r.id),
                onShowFullText: () => showFullTextDialog(context, r),
                onChatWithArticle: () => widget.onChatWithArticle(r.id),
                onDelete: () => _handleDelete(r.id),
                onViewOnWeb: () => _handleViewOnWeb(r.url),
                onRegenerate: () => _handleRegenerate(r.id),
                relatedArticles: _relatedMap[r.id],
                onShowRelatedFullText: (related) => showFullTextDialog(context, related),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  final ContentRecord record;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onShowFullText;
  final VoidCallback onChatWithArticle;
  final VoidCallback onDelete;
  final VoidCallback onViewOnWeb;
  final VoidCallback onRegenerate;
  final List<ContentRecord>? relatedArticles;
  final Function(ContentRecord) onShowRelatedFullText;

  const _ArchiveCard({
    required this.record,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onShowFullText,
    required this.onChatWithArticle,
    required this.onDelete,
    required this.onViewOnWeb,
    required this.onRegenerate,
    required this.relatedArticles,
    required this.onShowRelatedFullText,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final summary = r.data.firstSummary;
    final isRegenerating = r.data.processing && r.data.stage == 'Regenerating summary...';

    if (!isExpanded) {
      final collapsedContent = ContentCard(
        padding: const EdgeInsets.all(8),
        onTap: r.data.processing ? null : onToggleExpanded,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.data.thumbnail != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    r.data.thumbnail!,
                    height: 64,
                    width: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 64,
                      width: 64,
                      color: AppColors.slate800,
                    ),
                  ),
                )
              else
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: AppColors.slate800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (r.data.processing)
                          Pill(label: '🔄 ${r.data.stage ?? "Processing..."}')
                        else
                          TagBadge(tag: r.tag),
                        if (r.data.category != null) Pill(label: r.data.category!),
                      ],
                    ),
                    if (r.data.title != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        r.data.title!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate100,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (summary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Text('▸', style: TextStyle(color: AppColors.slate600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (r.data.original != null)
                TextButton(
                  onPressed: onChatWithArticle,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.indigo600,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Chat with this article',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              if (r.data.original != null)
                TextButton(
                  onPressed: onShowFullText,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.slate800,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('View full text',
                      style: TextStyle(color: AppColors.slate200, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              TextButton(
                onPressed: onViewOnWeb,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.slate800,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('View on web',
                    style: TextStyle(color: AppColors.slate200, fontSize: 11, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      );

      if (isRegenerating) {
        return IgnorePointer(
          ignoring: true,
          child: Opacity(
            opacity: 0.5,
            child: collapsedContent,
          ),
        );
      }
      return collapsedContent;
    }

    final expandedContent = ContentCard(
      children: [
        InkWell(
          onTap: onToggleExpanded,
          child: Row(
            children: [
              const Text('▾', style: TextStyle(color: AppColors.slate600, fontSize: 12)),
              const SizedBox(width: 8),
              if (r.data.processing)
                Pill(label: '🔄 ${r.data.stage ?? "Processing..."}')
              else
                TagBadge(tag: r.tag),
              if (r.data.category != null) ...[
                const SizedBox(width: 6),
                Pill(label: r.data.category!),
              ],
              if (r.data.embeddingError != null) ...[
                const SizedBox(width: 6),
                Pill(label: '⚠ 관련 기사 검색 제외'),
              ],
              const Spacer(),
              Text(
                DateFormat('MM/dd/yyyy, h:mm a').format(r.createdAt.toLocal()),
                style: const TextStyle(fontSize: 11, color: AppColors.slate600),
              ),
            ],
          ),
        ),
        if (r.data.title != null) ...[
          const SizedBox(height: 8),
          Text(
            r.data.title!,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate100),
          ),
        ],
        if (r.data.thumbnail != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              r.data.thumbnail!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
        if (summary != null) ...[
          const SizedBox(height: 8),
          Text(summary, style: const TextStyle(color: AppColors.slate200, height: 1.4)),
        ],
        if (relatedArticles != null && relatedArticles!.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            '관련 기사',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate400),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: relatedArticles!.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final rel = relatedArticles![idx];
                final relSummary = rel.data.firstSummary;
                return InkWell(
                  onTap: () => onShowRelatedFullText(rel),
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.slate800.withAlpha(180),
                      border: Border.all(color: AppColors.slate700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rel.data.thumbnail != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              rel.data.thumbnail!,
                              height: 60,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(height: 60, color: AppColors.slate700),
                            ),
                          )
                        else
                          Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.slate700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          rel.data.title ?? rel.url,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate100),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (relSummary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            relSummary,
                            style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (r.data.error != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.red950.withValues(alpha: 0.4),
              border: Border.all(color: AppColors.red900),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              r.data.error!,
              style: const TextStyle(color: AppColors.red400, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (r.data.original != null && !r.data.processing)
              ElevatedButton(
                onPressed: onRegenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.slate800,
                  foregroundColor: AppColors.indigo400,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Regenerate', style: TextStyle(fontSize: 12)),
              ),
            if (r.data.original != null)
              ElevatedButton(
                onPressed: onChatWithArticle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Chat with this article', style: TextStyle(fontSize: 12)),
              ),
            if (r.data.original != null)
              ElevatedButton(
                onPressed: onShowFullText,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.slate800,
                  foregroundColor: AppColors.slate200,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View full text', style: TextStyle(fontSize: 12)),
              ),
            ElevatedButton(
              onPressed: onViewOnWeb,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slate800,
                foregroundColor: AppColors.slate200,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('View on web', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: onDelete,
              child: const Text('Delete', style: TextStyle(color: AppColors.red400, fontSize: 12)),
            ),
          ],
        ),
      ],
    );

    if (isRegenerating) {
      return IgnorePointer(
        ignoring: true,
        child: Opacity(
          opacity: 0.5,
          child: expandedContent,
        ),
      );
    }
    return expandedContent;
  }
}
