import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_record.dart';
import '../services/content_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text);
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
      }
    });
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

  const _ArchiveCard({
    required this.record,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onShowFullText,
    required this.onChatWithArticle,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final summary = r.data.firstSummary;

    if (!isExpanded) {
      return ContentCard(
        padding: const EdgeInsets.all(8),
        onTap: onToggleExpanded,
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
                onPressed: () {},
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
    }

    return ContentCard(
      children: [
        InkWell(
          onTap: onToggleExpanded,
          child: Row(
            children: [
              const Text('▾', style: TextStyle(color: AppColors.slate600, fontSize: 12)),
              const SizedBox(width: 8),
              TagBadge(tag: r.tag),
              if (r.data.category != null) ...[
                const SizedBox(width: 6),
                Pill(label: r.data.category!),
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
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
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
              onPressed: () {},
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
              onPressed: () {},
              child: const Text('Delete', style: TextStyle(color: AppColors.red400, fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }
}
