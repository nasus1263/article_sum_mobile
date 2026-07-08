import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_record.dart';
import '../services/content_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/content_card.dart';
import '../widgets/full_text_dialog.dart';

class PendingPage extends StatefulWidget {
  const PendingPage({super.key});

  @override
  State<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends State<PendingPage> {
  final _repo = ContentRepository();
  List<ContentRecord>? _records;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      final records = await _repo.listByStatus('pending');
      if (!mounted) return;
      setState(() => _records = records);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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

    if (records.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Padding(
              padding: EdgeInsets.only(top: 32),
              child: Text(
                'No items pending approval. Try copying a link.',
                style: TextStyle(color: AppColors.slate500, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, i) => _PendingCard(
          record: records[i],
          onShowFullText: () => showFullTextDialog(context, records[i]),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final ContentRecord record;
  final VoidCallback onShowFullText;

  const _PendingCard({
    required this.record,
    required this.onShowFullText,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final summary = r.data.firstSummary;

    return ContentCard(
      children: [
        Row(
          children: [
            if (r.data.processing)
              Pill(label: r.data.stage ?? 'Processing...')
            else
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
        if (r.data.title != null) ...[
          const SizedBox(height: 8),
          Text(
            r.data.title!,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate100),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          r.url,
          style: const TextStyle(fontSize: 12, color: AppColors.indigo400),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (r.data.thumbnail != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              r.data.thumbnail!,
              height: 180,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (r.data.original != null)
              TextButton(
                onPressed: onShowFullText,
                child: const Text(
                  'Show full article',
                  style: TextStyle(color: AppColors.slate400, fontSize: 12),
                ),
              ),
            if (r.data.processing)
              TextButton(
                onPressed: () {},
                child: const Text('Cancel', style: TextStyle(color: AppColors.red400, fontSize: 12)),
              )
            else ...[
              TextButton(
                onPressed: () {},
                child: const Text('Discard', style: TextStyle(color: AppColors.red400, fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
