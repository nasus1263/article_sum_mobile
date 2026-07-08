import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_record.dart';
import '../services/content_repository.dart';
import '../services/pipeline_settings_store.dart';
import '../services/queue_events.dart';
import '../services/supabase_config.dart';
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
  String? _activeFolder;
  String _backendUrl = 'http://127.0.0.1:3000';
  PipelineSettings _pipelineSettings = const PipelineSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refresh();
    QueueEvents.updates.addListener(_refresh);
  }

  @override
  void dispose() {
    QueueEvents.updates.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final config = await SupabaseConfigStore.load();
    final pipelineSettings = await PipelineSettingsStore.load();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _backendUrl = config.cleanBackendUrl;
      _pipelineSettings = pipelineSettings;
      _activeFolder = prefs.getString('active_folder');
    });
  }

  Future<void> _saveActiveFolder(String? folder) async {
    final prefs = await SharedPreferences.getInstance();
    if (folder == null) {
      await prefs.remove('active_folder');
    } else {
      await prefs.setString('active_folder', folder);
    }
    setState(() => _activeFolder = folder);
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

  Future<void> _handleApprove(int id) async {
    try {
      await _repo.approve(id, folder: _activeFolder);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Approve failed: $e')));
    }
  }

  Future<void> _handleDiscard(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.slate900,
        title: const Text(
          'Discard this item?',
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
              'Discard',
              style: TextStyle(color: AppColors.red400),
            ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Discard failed: $e')));
    }
  }

  Future<void> _handleCancel(int id) async {
    try {
      await _repo.discard(
        id,
      ); // cancel on desktop aborts active job and discards the record
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    }
  }

  Future<void> _handleRegenerate(int id) async {
    try {
      // Run in background and update database state
      await _repo.regenerateSummary(
        id,
        _backendUrl,
        settings: _pipelineSettings,
        onProcessingStarted: _refresh,
      );
      await _refresh();
    } catch (e) {
      await _refresh(); // Refresh to show error on the card
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Regeneration failed: $e')));
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

    return Column(
      children: [
        // Active folder selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Text(
                'Approve into folder: ',
                style: TextStyle(
                  color: AppColors.slate400,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _activeFolder,
                  dropdownColor: AppColors.slate900,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppColors.slate900,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: AppColors.slate700),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: AppColors.slate700),
                    ),
                  ),
                  style: const TextStyle(
                    color: AppColors.slate100,
                    fontSize: 13,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No folder'),
                    ),
                    ..._pipelineSettings.categories.map(
                      (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: _saveActiveFolder,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: records.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Text(
                          'No items pending approval. Try copying a link.',
                          style: TextStyle(
                            color: AppColors.slate500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _PendingCard(
                      record: records[i],
                      onShowFullText: () =>
                          showFullTextDialog(context, records[i]),
                      onApprove: () => _handleApprove(records[i].id),
                      onDiscard: () => _handleDiscard(records[i].id),
                      onCancel: () => _handleCancel(records[i].id),
                      onRegenerate: () => _handleRegenerate(records[i].id),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  final ContentRecord record;
  final VoidCallback onShowFullText;
  final VoidCallback onApprove;
  final VoidCallback onDiscard;
  final VoidCallback onCancel;
  final VoidCallback onRegenerate;

  const _PendingCard({
    required this.record,
    required this.onShowFullText,
    required this.onApprove,
    required this.onDiscard,
    required this.onCancel,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final summary = r.data.firstSummary;

    Widget cardContent = ContentCard(
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.slate100,
            ),
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
          Text(
            summary,
            style: const TextStyle(color: AppColors.slate200, height: 1.4),
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
            if (r.data.original != null && !r.data.processing)
              TextButton(
                onPressed: onRegenerate,
                child: const Text(
                  'Regenerate',
                  style: TextStyle(color: AppColors.indigo400, fontSize: 12),
                ),
              ),
            if (r.data.processing)
              TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.red400, fontSize: 12),
                ),
              )
            else ...[
              TextButton(
                onPressed: onDiscard,
                child: const Text(
                  'Discard',
                  style: TextStyle(color: AppColors.red400, fontSize: 12),
                ),
              ),
              ElevatedButton(
                onPressed: onApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Approve',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
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
            child: Opacity(opacity: 0.5, child: cardContent),
          ),
          const CircularProgressIndicator(color: AppColors.indigo500),
        ],
      );
    }
    return cardContent;
  }
}
