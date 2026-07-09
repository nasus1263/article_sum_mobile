import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_record.dart';
import '../pages/archive_detail_page.dart';
import '../services/content_repository.dart';
import '../services/pipeline_settings_store.dart';
import '../services/supabase_config.dart';
import '../theme/app_colors.dart';
import '../widgets/content_card.dart';

enum ArchiveVariant {
  categories,
  archive,
  favorites,
}

class ArchivePage extends StatefulWidget {
  final ValueChanged<int> onChatWithArticle;
  final ArchiveVariant variant;

  const ArchivePage({
    super.key,
    required this.onChatWithArticle,
    this.variant = ArchiveVariant.archive,
  });

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

/// Sentinel for the folder filter's "None" option (items with no folder
/// assigned), distinct from `null` which means "ALL" (no filter applied).
const _kNoFolder = ' __no_folder__';

class _ArchivePageState extends State<ArchivePage> {
  final _repo = ContentRepository();
  List<ContentRecord>? _records;
  String? _error;
  final _searchController = TextEditingController();
  String _search = '';
  final Set<String> _categoryFilter = {};
  String? _folderFilter;
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

  void _selectFolder(String? folder) {
    setState(() => _folderFilter = folder);
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

  Widget _buildCategoriesView(List<ContentRecord> records) {
    final categoryGroups = <String, List<ContentRecord>>{};
    for (final r in records) {
      final category = r.data.category ?? 'Uncategorized';
      categoryGroups.putIfAbsent(category, () => []).add(r);
    }
    final sortedKeys = categoryGroups.keys.toList()..sort();

    if (sortedKeys.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            Padding(
              padding: EdgeInsets.only(top: 32),
              child: Text(
                'No categories available.',
                style: TextStyle(color: AppColors.slate500, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final category = sortedKeys[index];
          final articles = categoryGroups[category]!;
          final count = articles.length;
          final latest = articles.first;

          return InkWell(
            onTap: () => _openDetail(latest),
            borderRadius: BorderRadius.circular(2),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                border: Border.all(color: AppColors.slate800),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate100,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.more_horiz, color: AppColors.slate500, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count saved articles',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.slate500,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'LATEST',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.indigo400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    latest.data.title ?? latest.url,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.slate300,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

    final rawRecords = _records;
    if (rawRecords == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.indigo500),
      );
    }

    // Filter records for favorites variant
    var records = rawRecords;
    if (widget.variant == ArchiveVariant.favorites) {
      records = rawRecords.where((r) => r.favoritedAt != null).toList();
      records.sort((a, b) {
        if (a.favoritedAt == null && b.favoritedAt == null) return 0;
        if (a.favoritedAt == null) return 1;
        if (b.favoritedAt == null) return -1;
        return b.favoritedAt!.compareTo(a.favoritedAt!);
      });
    }

    // Extract sorted categories
    final categoriesSet = <String>{};
    for (final r in records) {
      if (r.data.category != null) categoriesSet.add(r.data.category!);
    }
    final sortedCategories = categoriesSet.toList()..sort();

    final query = _search.trim().toLowerCase();
    final filtered = records.where((r) {
      if (_categoryFilter.isNotEmpty &&
          !(r.data.category != null &&
              _categoryFilter.contains(r.data.category))) {
        return false;
      }
      if (_folderFilter == _kNoFolder && r.data.folder != null) {
        return false;
      }
      if (_folderFilter != null &&
          _folderFilter != _kNoFolder &&
          r.data.folder != _folderFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final summary = r.data.firstSummary?.toLowerCase() ?? '';
      return r.url.toLowerCase().contains(query) || summary.contains(query);
    }).toList();

    // If variant is categories, show categories view directly (no search bar, no pills)
    if (widget.variant == ArchiveVariant.categories) {
      return _buildCategoriesView(filtered);
    }

    // Otherwise, build the Archive/Favorites flat list with search bar + pills + featured item
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
                borderRadius: BorderRadius.all(Radius.circular(2)),
                borderSide: BorderSide(color: AppColors.slate700),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(2)),
                borderSide: BorderSide(color: AppColors.slate700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(2)),
                borderSide: BorderSide(color: AppColors.indigo500),
              ),
            ),
          ),
          if (sortedCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4, right: 8),
                  child: Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
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
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  'Folder',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate500,
                  ),
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(
                      label: 'ALL',
                      active: _folderFilter == null,
                      onTap: () => _selectFolder(null),
                    ),
                    Pill(
                      label: 'None',
                      active: _folderFilter == _kNoFolder,
                      onTap: () => _selectFolder(_kNoFolder),
                    ),
                    ..._pipelineSettings.folders.map(
                      (f) => Pill(
                        label: f,
                        active: _folderFilter == f,
                        onTap: () => _selectFolder(f),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (records.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text(
                  widget.variant == ArchiveVariant.favorites
                      ? 'No favorite articles yet.'
                      : 'No archived items.',
                  style: const TextStyle(color: AppColors.slate500, fontSize: 13),
                ),
              ),
            )
          else if (filtered.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 32),
                child: Text(
                  'No items match your search/filter.',
                  style: TextStyle(color: AppColors.slate500, fontSize: 13),
                ),
              ),
            )
          else ...[
            // Featured Card on top
            _FeaturedCard(
              record: filtered.first,
              onTap: () => _openDetail(filtered.first),
              onToggleFavorite: _refresh,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  widget.variant == ArchiveVariant.favorites
                      ? 'FAVORITES'
                      : 'ARCHIVE',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate500,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Remaining items as vertical list
            for (final r in filtered.skip(1)) ...[
              _ArchiveCard(
                record: r,
                onTap: () => _openDetail(r),
                onViewOnWeb: () => _handleViewOnWeb(r.url),
                onToggleFavorite: _refresh,
              ),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final ContentRecord record;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _FeaturedCard({
    required this.record,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final summary = r.data.firstSummary;
    final image = r.data.firstImage;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slate900,
          border: Border.all(color: AppColors.slate800),
          borderRadius: BorderRadius.circular(2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null)
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0,      0,      0,      1, 0,
                ]),
                child: Image.network(
                  image,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    color: AppColors.slate800,
                    child: const Center(child: Icon(Icons.image, color: AppColors.slate600)),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.slate800, AppColors.slate900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Pill(label: r.data.category ?? 'FEATURED'),
                      FavoriteStar(record: r, onToggle: onToggleFavorite),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (r.data.title != null)
                    Text(
                      r.data.title!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate100,
                      ),
                    ),
                  if (summary != null) ...[
                    const SizedBox(height: 6),
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
          ],
        ),
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  final ContentRecord record;
  final VoidCallback onTap;
  final VoidCallback onViewOnWeb;
  final VoidCallback onToggleFavorite;

  const _ArchiveCard({
    required this.record,
    required this.onTap,
    required this.onViewOnWeb,
    required this.onToggleFavorite,
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
            Column(
              children: [
                FavoriteStar(record: r, onToggle: onToggleFavorite),
                const Text(
                  '▸',
                  style: TextStyle(color: AppColors.slate600, fontSize: 12),
                ),
              ],
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
          borderRadius: BorderRadius.circular(2),
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
                  borderRadius: BorderRadius.circular(2),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0,      0,      0,      1, 0,
              ]),
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
          ),
        ],
      ),
    );
  }
}
