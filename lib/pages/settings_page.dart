import 'package:flutter/material.dart';

import '../constants/pipeline_defaults.dart';
import '../services/chat_config.dart';
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

  // Display-only pipeline defaults — not persisted, not wired to a backend.
  final bool _emoji = true;
  final bool _kidFriendly = false;
  final String _language = 'ko';
  final String _provider = 'claude';
  final List<String> _categories = List.of(kDefaultCategories);
  final _newCategoryController = TextEditingController();

  final Map<String, TextEditingController> _apiKeyControllers = {
    for (final p in kProviders) p.id: TextEditingController(),
  };
  final Map<String, TextEditingController> _modelControllers = {
    for (final p in kProviders) p.id: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await SupabaseConfigStore.load();
    final apiKeys = await ChatConfigStore.loadApiKeys();
    final models = await ChatConfigStore.loadModels();
    if (!mounted) return;
    _backendUrlController.text = config.backendUrl;
    for (final p in kProviders) {
      _apiKeyControllers[p.id]!.text = apiKeys[p.id] ?? '';
      _modelControllers[p.id]!.text = models[p.id] ?? kDefaultModels[p.id]!;
    }
    setState(() => _loaded = true);
  }

  Future<void> _saveConfig() async {
    final config = await SupabaseConfigStore.load();
    await SupabaseConfigStore.save(
      config.copyWith(backendUrl: _backendUrlController.text),
    );
  }

  Future<void> _saveApiKeys() async {
    await ChatConfigStore.saveApiKeys({
      for (final p in kProviders) p.id: _apiKeyControllers[p.id]!.text,
    });
  }

  Future<void> _saveModels() async {
    await ChatConfigStore.saveModels({
      for (final p in kProviders) p.id: _modelControllers[p.id]!.text,
    });
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _newCategoryController.dispose();
    for (final c in _apiKeyControllers.values) {
      c.dispose();
    }
    for (final c in _modelControllers.values) {
      c.dispose();
    }
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
      return const Center(child: CircularProgressIndicator(color: AppColors.indigo500));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.slate200)),
        const SizedBox(height: 24),

        const Text('Pipeline defaults',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate200)),
        const SizedBox(height: 12),
        ContentCard(
          children: [
            CheckboxListTile(
              value: _emoji,
              onChanged: (_) {},
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.indigo500,
              title: const Text('Add emojis', style: TextStyle(color: AppColors.slate200, fontSize: 13)),
            ),
            CheckboxListTile(
              value: _kidFriendly,
              onChanged: (_) {},
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.indigo500,
              title: const Text('Kid-friendly (simple words)',
                  style: TextStyle(color: AppColors.slate200, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Summary language', style: TextStyle(color: AppColors.slate300, fontSize: 13)),
                const Spacer(),
                DropdownButton<String>(
                  value: _language,
                  dropdownColor: AppColors.slate900,
                  style: const TextStyle(color: AppColors.slate100, fontSize: 13),
                  underline: const SizedBox.shrink(),
                  items: kLanguages
                      .map((l) => DropdownMenuItem(value: l.id, child: Text(l.label)))
                      .toList(),
                  onChanged: (_) {},
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Provider', style: TextStyle(color: AppColors.slate300, fontSize: 13)),
                const Spacer(),
                DropdownButton<String>(
                  value: _provider,
                  dropdownColor: AppColors.slate900,
                  style: const TextStyle(color: AppColors.slate100, fontSize: 13),
                  underline: const SizedBox.shrink(),
                  items: kProviders
                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.label)))
                      .toList(),
                  onChanged: (_) {},
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate200)),
        const SizedBox(height: 12),
        ContentCard(
          children: [
            for (var i = 0; i < _categories.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: _categories[i]),
                        onChanged: (_) {},
                        style: const TextStyle(color: AppColors.slate100, fontSize: 13),
                        decoration: _fieldDecoration(),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Remove', style: TextStyle(color: AppColors.red400, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    style: const TextStyle(color: AppColors.slate100, fontSize: 13),
                    decoration: _fieldDecoration(hint: 'New category'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text('Backend Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate200)),
        const SizedBox(height: 12),
        ContentCard(
          children: [
            const Text('Backend URL', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _backendUrlController,
              style: const TextStyle(color: AppColors.slate100, fontSize: 13),
              decoration: _fieldDecoration(hint: 'http://127.0.0.1:3000'),
              onChanged: (_) => _saveConfig(),
            ),
          ],
        ),

        const SizedBox(height: 24),
        for (final p in kProviders) ...[
          ContentCard(
            children: [
              Text(p.label, style: const TextStyle(color: AppColors.slate300, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              const Text('API Key', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyControllers[p.id],
                obscureText: true,
                onChanged: (_) => _saveApiKeys(),
                style: const TextStyle(color: AppColors.slate100, fontSize: 13),
                decoration: _fieldDecoration(hint: '${p.label} API Key'),
              ),
              const SizedBox(height: 12),
              const Text('Model name', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _modelControllers[p.id],
                onChanged: (_) => _saveModels(),
                style: const TextStyle(color: AppColors.slate100, fontSize: 13),
                decoration: _fieldDecoration(),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
