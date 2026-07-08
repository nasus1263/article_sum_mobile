import 'package:flutter/material.dart';

import '../constants/pipeline_defaults.dart';
import '../services/pipeline_settings_store.dart';
import '../services/supabase_config.dart';
import '../theme/app_colors.dart';
import '../widgets/content_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _backendUrlController = TextEditingController();
  bool _loaded = false;

  PipelineSettings _pipeline = const PipelineSettings();
  final _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await SupabaseConfigStore.load();
    final pipeline = await PipelineSettingsStore.load();
    if (!mounted) return;
    _backendUrlController.text = config.backendUrl;
    setState(() {
      _pipeline = pipeline;
      _loaded = true;
    });
  }

  Future<void> _saveConfig() async {
    final config = await SupabaseConfigStore.load();
    await SupabaseConfigStore.save(
      config.copyWith(backendUrl: _backendUrlController.text),
    );
  }

  Future<void> _updatePipeline(PipelineSettings next) async {
    setState(() => _pipeline = next);
    await PipelineSettingsStore.save(next);
  }

  void _renameCategory(int index, String value) {
    final next = List.of(_pipeline.categories);
    next[index] = value;
    _updatePipeline(_pipeline.copyWith(categories: next));
  }

  void _removeCategory(int index) {
    final next = List.of(_pipeline.categories)..removeAt(index);
    _updatePipeline(_pipeline.copyWith(categories: next));
  }

  void _addCategory() {
    final trimmed = _newCategoryController.text.trim();
    if (trimmed.isEmpty || _pipeline.categories.contains(trimmed)) return;
    _updatePipeline(
      _pipeline.copyWith(categories: [..._pipeline.categories, trimmed]),
    );
    _newCategoryController.clear();
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.slate500),
      filled: true,
      fillColor: AppColors.slate900,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.slate700),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.slate700),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.indigo500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.indigo500),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.slate200,
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Pipeline defaults',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.slate200,
          ),
        ),
        const SizedBox(height: 12),
        ContentCard(
          children: [
            CheckboxListTile(
              value: _pipeline.emoji,
              onChanged: (v) => _updatePipeline(
                _pipeline.copyWith(emoji: v ?? _pipeline.emoji),
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.indigo500,
              title: const Text(
                'Add emojis',
                style: TextStyle(color: AppColors.slate200, fontSize: 13),
              ),
            ),
            CheckboxListTile(
              value: _pipeline.kidFriendly,
              onChanged: (v) => _updatePipeline(
                _pipeline.copyWith(kidFriendly: v ?? _pipeline.kidFriendly),
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.indigo500,
              title: const Text(
                'Kid-friendly (simple words)',
                style: TextStyle(color: AppColors.slate200, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Summary language',
                  style: TextStyle(color: AppColors.slate300, fontSize: 13),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _pipeline.language,
                  dropdownColor: AppColors.slate900,
                  style: const TextStyle(
                    color: AppColors.slate100,
                    fontSize: 13,
                  ),
                  underline: const SizedBox.shrink(),
                  items: kLanguages
                      .map(
                        (l) =>
                            DropdownMenuItem(value: l.id, child: Text(l.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _updatePipeline(_pipeline.copyWith(language: v));
                    }
                  },
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text(
          'Categories',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.slate200,
          ),
        ),
        const SizedBox(height: 12),
        ContentCard(
          children: [
            for (var i = 0; i < _pipeline.categories.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('category_$i'),
                        controller: TextEditingController(
                          text: _pipeline.categories[i],
                        ),
                        onChanged: (v) => _renameCategory(i, v),
                        style: const TextStyle(
                          color: AppColors.slate100,
                          fontSize: 13,
                        ),
                        decoration: _fieldDecoration(),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _removeCategory(i),
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: AppColors.red400, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    style: const TextStyle(
                      color: AppColors.slate100,
                      fontSize: 13,
                    ),
                    decoration: _fieldDecoration(hint: 'New category'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text(
          'Backend Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.slate200,
          ),
        ),
        const SizedBox(height: 12),
        ContentCard(
          children: [
            const Text(
              'Backend URL',
              style: TextStyle(color: AppColors.slate500, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _backendUrlController,
              style: const TextStyle(color: AppColors.slate100, fontSize: 13),
              decoration: _fieldDecoration(hint: 'http://127.0.0.1:3000'),
              onChanged: (_) => _saveConfig(),
            ),
          ],
        ),
      ],
    );
  }
}
