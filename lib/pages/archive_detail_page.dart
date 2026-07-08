import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_record.dart';
import '../services/content_repository.dart';
import '../services/pipeline_settings_store.dart';
import '../theme/app_colors.dart';
import '../widgets/content_card.dart';
import '../widgets/full_text_dialog.dart';

/// Full-screen detail view for an archived item, mirroring article-sum's
/// ArchiveDetail.tsx: Archive's card list now only navigates here instead of
/// expanding in place.
class ArchiveDetailPage extends StatefulWidget {
  final ContentRecord record;
  final String backendUrl;
  final PipelineSettings pipelineSettings;
  final ValueChanged<int> onChatWithArticle;

  const ArchiveDetailPage({
    super.key,
    required this.record,
    required this.backendUrl,
    required this.pipelineSettings,
    required this.onChatWithArticle,
  });

  @override
  State<ArchiveDetailPage> createState() => _ArchiveDetailPageState();
}

class _ArchiveDetailPageState extends State<ArchiveDetailPage> {
  final _repo = ContentRepository();
  late ContentRecord _record;
  List<ContentRecord> _related = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _fetchRelated();
  }

  Future<void> _fetchRelated() async {
    try {
      final related = await _repo.getRelated(_record.id);
      if (!mounted) return;
      setState(() => _related = related);
    } catch (_) {
      // Ignore errors fetching related articles gracefully
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.slate900,
        title: const Text(
          'Delete this item?',
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

    try {
      await _repo.discard(_record.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _handleRegenerate() async {
    setState(() => _busy = true);
    try {
      await _repo.regenerateSummary(
        _record.id,
        widget.backendUrl,
        settings: widget.pipelineSettings,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Regeneration failed: $e')));
    }
  }

  Future<void> _handleViewOnWeb() async {
    final uri = Uri.parse(_record.url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch ${_record.url}';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    final summary = r.data.firstSummary;
    final images = r.data.images;

    return Scaffold(
      appBar: AppBar(title: const Text('Archived item')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ContentCard(
              children: [
                Row(
                  children: [
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
                      DateFormat(
                        'MM/dd/yyyy, h:mm a',
                      ).format(r.createdAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
                if (r.data.title != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    r.data.title!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate100,
                    ),
                  ),
                ],
                if (images != null && images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          images[i],
                          height: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ],
                if (summary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    style: const TextStyle(
                      color: AppColors.slate200,
                      height: 1.4,
                    ),
                  ),
                ],
                if (_related.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '관련 기사',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _related.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final rel = _related[idx];
                        final relSummary = rel.data.firstSummary;
                        return InkWell(
                          onTap: () => showFullTextDialog(context, rel),
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
                                if (rel.data.firstImage != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      rel.data.firstImage!,
                                      height: 60,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 60,
                                        color: AppColors.slate700,
                                      ),
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
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.slate100,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (relSummary != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    relSummary,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.slate400,
                                    ),
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
                      r.data.error!,
                      style: const TextStyle(
                        color: AppColors.red400,
                        fontSize: 13,
                      ),
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
                        onPressed: _busy ? null : _handleRegenerate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.slate800,
                          foregroundColor: AppColors.indigo400,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Regenerate',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    if (r.data.original != null)
                      ElevatedButton(
                        onPressed: () => widget.onChatWithArticle(r.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.indigo600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Chat with this article',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    if (r.data.original != null)
                      ElevatedButton(
                        onPressed: () => showFullTextDialog(context, r),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.slate800,
                          foregroundColor: AppColors.slate200,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View full text',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _handleViewOnWeb,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.slate800,
                        foregroundColor: AppColors.slate200,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'View on web',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _handleDelete,
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: AppColors.red400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
