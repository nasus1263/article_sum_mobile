import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_record.dart';
import '../pages/archive_detail_page.dart';
import '../services/content_repository.dart';
import '../services/pipeline_settings_store.dart';
import '../services/supabase_config.dart';
import '../theme/app_colors.dart';
import '../widgets/content_card.dart';

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
  String _backendUrl = kDefaultBackendUrl;
  PipelineSettings _pipelineSettings = const PipelineSettings();

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
    final pipelineSettings = await PipelineSettingsStore.load();
    if (!mounted) return;
    setState(() {
      _backendUrl = config.cleanBackendUrl;
      _pipelineSettings = pipelineSettings;
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

  void _toggleCategory(String category) {
    setState(() {
      if (_categoryFilter.contains(category)) {
        _categoryFilter.remove(category);
      } else {
        _categoryFilter.add(category);
      }
    });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
    }
  }

  Future<void> _openDetail(ContentRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArchiveDetailPage(
          record: record,
          backendUrl: _backendUrl,
          pipelineSettings: _pipelineSettings,
          onChatWithArticle: widget.onChatWithArticle,
        ),
      ),
    );
    await _refresh();
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
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.slate400, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final records = _records;
    if (records == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.indigo500),
      );
    }

    final categories = <String>{};
    for (final r in records) {
      if (r.data.category != null) categories.add(r.data.category!);
    }
    final sortedCategories = categories.toList()..sort();

    final query = _search.trim().toLowerCase();
    final filtered = records.where((r) {
      if (_categoryFilter.isNotEmpty &&
          !(r.data.category != null &&
              _categoryFilter.contains(r.data.category))) {
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
                  .map(
                    (c) => Pill(
                      label: c,
                      active: _categoryFilter.contains(c),
                      onTap: () => _toggleCategory(c),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          if (records.isEmpty)
            const Text(
              'No archived items.',
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
          if (records.isNotEmpty && filtered.isEmpty)
            const Text(
              'No items match your search/filter.',
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
          for (final folder in folders) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                folder,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate400,
                ),
              ),
            ),
            for (final r in groups[folder]!) ...[
              _ArchiveCard(
                record: r,
                onTap: () => _openDetail(r),
                onViewOnWeb: () => _handleViewOnWeb(r.url),
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
  final VoidCallback onTap;
  final VoidCallback onViewOnWeb;

  const _ArchiveCard({
    required this.record,
    required this.onTap,
    required this.onViewOnWeb,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final summary = r.data.firstSummary;
    final images = r.data.images;

    final content = ContentCard(
      padding: const EdgeInsets.all(8),
      onTap: r.data.processing ? null : onTap,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ArchiveThumbnail(images: images),
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
                      if (r.data.category != null)
                        Pill(label: r.data.category!),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate400,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Text(
              '▸',
              style: TextStyle(color: AppColors.slate600, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onViewOnWeb,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.slate800,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
              ),
              child: const Text(
                'View on web',
                style: TextStyle(
                  color: AppColors.slate200,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (r.data.processing) {
      return Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            ignoring: true,
            child: Opacity(opacity: 0.5, child: content),
          ),
          const CircularProgressIndicator(color: AppColors.indigo500),
        ],
      );
    }
    return content;
  }
}

/// Renders the collapsed-card thumbnail. When there's more than one image,
/// adds two rotated cards behind the main image to hint at a stack, mirroring
/// article-sum's Archive.tsx multi-image treatment.
class _ArchiveThumbnail extends StatelessWidget {
  final List<String>? images;

  const _ArchiveThumbnail({required this.images});

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    if (images == null || images!.isEmpty) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (images!.length > 1) ...[
            Transform.rotate(
              angle: 0.35,
              child: Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  color: AppColors.slate800,
                  border: Border.all(color: AppColors.slate700),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Transform.rotate(
              angle: 0.17,
              child: Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  color: AppColors.slate800,
                  border: Border.all(color: AppColors.slate700),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              images!.first,
              height: size,
              width: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: size,
                width: size,
                color: AppColors.slate800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
