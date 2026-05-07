import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/ai_settings_provider.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final TextEditingController _keyController;
  late final TextEditingController _customModelController;
  bool _obscureKey = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final ai = context.read<AiSettingsProvider>();
    _keyController = TextEditingController(text: ai.apiKey);
    final isPreset = AiSettingsProvider.presets.any(
      (p) => p.id == ai.modelId,
    );
    _customModelController =
        TextEditingController(text: isPreset ? '' : ai.modelId);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    HapticFeedback.selectionClick();
    final ai = context.read<AiSettingsProvider>();
    await ai.setApiKey(_keyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('API anahtarı kaydedildi.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _saveCustomModel() async {
    HapticFeedback.selectionClick();
    final ai = context.read<AiSettingsProvider>();
    final v = _customModelController.text.trim();
    if (v.isEmpty) return;
    await ai.setModelId(v);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Model güncellendi: $v'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _test() async {
    final ai = context.read<AiSettingsProvider>();
    if (ai.apiKey.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Önce API anahtarı girin.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    setState(() => _testing = true);
    HapticFeedback.selectionClick();
    final result = await ai.testConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(result),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
  }

  Future<void> _openOpenRouterKeysPage() async {
    final uri = Uri.parse('https://openrouter.ai/keys');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Tarayıcı açılamadı'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSettingsProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yapay Zeka Özetleme'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ─────────── Etkin/Pasif ───────────
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: const Text('Yapay zeka özetlerini etkinleştir'),
            subtitle: const Text(
              'Detay ekranında "Yapay zekayla özetle" butonu görünür.',
            ),
            value: ai.enabled,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              context.read<AiSettingsProvider>().setEnabled(v);
            },
          ),
          if (ai.keySource != AiKeySource.none)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ai.keySource == AiKeySource.userProvided
                      ? cs.primary.withValues(alpha: 0.10)
                      : Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      ai.keySource == AiKeySource.userProvided
                          ? Icons.person_outline
                          : Icons.verified_outlined,
                      size: 16,
                      color: ai.keySource == AiKeySource.userProvided
                          ? cs.primary
                          : Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ai.keySource == AiKeySource.userProvided
                            ? 'Kişisel API anahtarınız kullanılıyor.'
                            : 'Uygulama içi gömülü anahtar kullanılıyor — '
                                'kendi anahtarınızı girmeniz gerekmiyor.',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 1, indent: 20, endIndent: 20),

          // ─────────── Sağlayıcı bilgi kartı ───────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_outlined,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Sağlayıcı: OpenRouter',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tek API anahtarıyla 100+ AI modeline erişim sağlar '
                    '(Anthropic, OpenAI, Google, Meta, DeepSeek vb.). '
                    'Anahtar https://openrouter.ai/keys adresinden alınır.\n\n'
                    'Geliştirici iseniz: kök dizindeki .env.json.example\'ı '
                    '.env.json olarak kopyalayıp anahtarınızı oraya yazın; '
                    'VSCode\'da F5 ile her seferinde otomatik yüklenir.',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _openOpenRouterKeysPage,
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('OpenRouter API anahtarı al'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─────────── API Key alanı ───────────
          const _SectionTitle('API Anahtarı'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _keyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: 'sk-or-v1-...',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  tooltip: _obscureKey ? 'Göster' : 'Gizle',
                  icon: Icon(
                    _obscureKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _saveKey(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _saveKey,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Kaydet'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_outlined, size: 18),
                  label: Text(_testing ? 'Test ediliyor' : 'Bağlantıyı test et'),
                ),
              ],
            ),
          ),
          if (ai.lastError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 18, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ai.lastError!,
                        style: TextStyle(
                          color: cs.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          context.read<AiSettingsProvider>().clearError(),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),

          // ─────────── Model seçimi ───────────
          const _SectionTitle('Model'),
          for (final p in AiSettingsProvider.presets)
            _ModelTile(
              preset: p,
              selected: ai.modelId == p.id,
              onTap: () =>
                  context.read<AiSettingsProvider>().setModelId(p.id),
            ),
          const _SectionTitle('Diğer model (custom)'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _customModelController,
              decoration: InputDecoration(
                hintText: 'provider/model-id',
                helperText: 'Örn: mistralai/mistral-large, x-ai/grok-2-1212',
                prefixIcon: const Icon(Icons.code),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _saveCustomModel(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _saveCustomModel,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Custom model\'i uygula'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─────────── Cache yönetimi ───────────
          const _SectionTitle('Önbellek'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Üretilmiş özetleri temizle'),
            subtitle: const Text(
              'Tüm haberler için cache\'lenmiş AI özetleri silinir.',
            ),
            onTap: () async {
              HapticFeedback.lightImpact();
              await context.read<AiSettingsProvider>().clearCache();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('AI özet önbelleği temizlendi.'),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AiModelPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.5),
            width: 2,
          ),
          color: selected ? cs.primary : Colors.transparent,
        ),
        child: selected
            ? Icon(Icons.check, size: 14, color: cs.onPrimary)
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              preset.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _tierColor(cs, preset.tier).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              preset.tier.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _tierColor(cs, preset.tier),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        preset.description,
        style: const TextStyle(fontSize: 12, height: 1.35),
      ),
    );
  }

  Color _tierColor(ColorScheme cs, AiModelTier tier) {
    return switch (tier) {
      AiModelTier.fast => Colors.green.shade700,
      AiModelTier.balanced => cs.primary,
      AiModelTier.premium => Colors.orange.shade700,
      AiModelTier.free => Colors.purple.shade700,
    };
  }
}
