import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tts/briefing_audio_cache.dart';
import '../../data/repositories/openai_tts_service.dart';
import '../../data/repositories/openrouter_models_repository.dart';
import '../../providers/ai_settings_provider.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final TextEditingController _keyController;
  late final TextEditingController _customModelController;
  late final TextEditingController _openaiTtsKeyController;
  bool _obscureKey = true;
  bool _obscureTtsKey = true;
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
    _openaiTtsKeyController =
        TextEditingController(text: ai.openaiTtsKey);

    // Ekran açıldığında live OpenRouter listesini bir kez çekelim.
    // Cache valid ise tekrar çağrı yapmaz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ai.loadOpenRouterModels();
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _customModelController.dispose();
    _openaiTtsKeyController.dispose();
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

  Future<void> _saveTtsKey() async {
    HapticFeedback.selectionClick();
    final ai = context.read<AiSettingsProvider>();
    await ai.setOpenaiTtsKey(_openaiTtsKeyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('OpenAI TTS anahtarı kaydedildi.'),
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
          // ─────────── Aktif anahtar mod toggle'ı ───────────
          // Kullanıcı default'ta env-embedded anahtarı kullanır.
          // İstediğinde "Kendi anahtarım"a geçer (eski anahtar silinmez,
          // sadece pasifleşir).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AKTİF ANAHTAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ApiKeyMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ApiKeyMode.builtIn,
                      icon: Icon(Icons.verified_outlined, size: 16),
                      label: Text('Varsayılan'),
                    ),
                    ButtonSegment(
                      value: ApiKeyMode.userProvided,
                      icon: Icon(Icons.person_outline, size: 16),
                      label: Text('Kendi anahtarım'),
                    ),
                  ],
                  selected: {ai.apiKeyMode},
                  onSelectionChanged: (set) {
                    HapticFeedback.selectionClick();
                    context
                        .read<AiSettingsProvider>()
                        .setApiKeyMode(set.first);
                  },
                ),
              ],
            ),
          ),
          // Aktif mod durumu — uyarı + bilgi banner'ı.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _ApiKeyModeStatus(
              mode: ai.apiKeyMode,
              hasBuiltIn: ai.hasBuiltInKey,
              hasUserKey: ai.hasUserApiKey,
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
          // API Key alanı sadece "Kendi anahtarım" modunda görünür.
          // Default modda kullanıcının elle anahtar girmesine gerek yok.
          if (ai.apiKeyMode == ApiKeyMode.userProvided) ...[
            const _SectionTitle('Kişisel API Anahtarınız'),
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
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt_outlined, size: 18),
                    label: Text(_testing
                        ? 'Test ediliyor'
                        : 'Bağlantıyı test et'),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Default mod: küçük bilgi + sadece "test et" butonu.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt_outlined, size: 18),
                    label: Text(_testing
                        ? 'Test ediliyor'
                        : 'Varsayılan anahtarı test et'),
                  ),
                ],
              ),
            ),
          ],
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
          const _SectionTitle('Hazır model presetleri'),
          for (final p in AiSettingsProvider.presets)
            _ModelTile(
              preset: p,
              selected: ai.modelId == p.id,
              onTap: () =>
                  context.read<AiSettingsProvider>().setModelId(p.id),
            ),

          // ─────────── Canlı OpenRouter listesi ───────────
          _LiveModelSection(currentModelId: ai.modelId),

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

          // ─────────── Sesli okuma motoru ───────────
          const _SectionTitle('Sesli okuma motoru'),
          for (final kind in TtsEngineKind.values)
            _TtsEngineTile(
              kind: kind,
              selected: ai.ttsEngine == kind,
              onTap: () =>
                  context.read<AiSettingsProvider>().setTtsEngine(kind),
            ),
          if (ai.ttsEngine == TtsEngineKind.openai) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'OpenAI TTS yapılandırması',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sesli brifing OpenAI sunucularında üretilen MP3\'ten '
                      'çalınır. Anahtar OpenRouter\'dan ayrı bir OpenAI '
                      'anahtarıdır (https://platform.openai.com/api-keys).',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _openaiTtsKeyController,
                obscureText: _obscureTtsKey,
                decoration: InputDecoration(
                  labelText: 'OpenAI API anahtarı',
                  hintText: 'sk-proj-...',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureTtsKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscureTtsKey = !_obscureTtsKey),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _saveTtsKey(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _saveTtsKey,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('OpenAI TTS anahtarını kaydet'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Ses karakteri',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            for (final v in OpenAiTtsService.voices)
              _SimpleRadioTile(
                title: v.label,
                subtitle: v.description,
                selected: ai.openaiTtsVoice == v.id,
                onTap: () => context
                    .read<AiSettingsProvider>()
                    .setOpenaiTtsVoice(v.id),
              ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Model',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            for (final m in OpenAiTtsService.models)
              _SimpleRadioTile(
                title: m.label,
                subtitle: m.description,
                selected: ai.openaiTtsModel == m.id,
                onTap: () => context
                    .read<AiSettingsProvider>()
                    .setOpenaiTtsModel(m.id),
              ),
            const SizedBox(height: 12),
          ],
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
          const _AudioCacheTile(),
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

/// OpenRouter `/api/v1/models` endpoint'inden gelen canlı model listesi.
///
/// Üç durum:
///   1. İlk açılış (loading) → spinner
///   2. Liste hazır → "Sadece ücretsiz" filter chip'i + arama + scrollable liste
///   3. Hata → tekrar dene butonu
class _LiveModelSection extends StatefulWidget {
  const _LiveModelSection({required this.currentModelId});
  final String currentModelId;

  @override
  State<_LiveModelSection> createState() => _LiveModelSectionState();
}

class _LiveModelSectionState extends State<_LiveModelSection> {
  bool _onlyFree = true;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ai = context.watch<AiSettingsProvider>();

    final all = ai.availableModels;
    final filtered = all.where((m) {
      if (_onlyFree && !m.isFree) return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return m.id.toLowerCase().contains(q) ||
          m.name.toLowerCase().contains(q);
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Row(
            children: [
              Text(
                'CANLI OPENROUTER LİSTESİ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (ai.modelsLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Yenile',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => context
                      .read<AiSettingsProvider>()
                      .loadOpenRouterModels(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
        ),
        if (ai.modelsError != null && all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ai.modelsError!,
                      style: TextStyle(
                          color: cs.onErrorContainer, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context
                        .read<AiSettingsProvider>()
                        .loadOpenRouterModels(forceRefresh: true),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          )
        else if (all.isEmpty && ai.modelsLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Canlı model listesi yükleniyor…')),
          )
        else if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Liste boş.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          )
        else ...[
          if (!ai.isCurrentModelValid)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Şu an seçili model "${widget.currentModelId}" '
                        'OpenRouter listesinde yok — emekli edilmiş '
                        'olabilir. Aşağıdan başka bir model seçin.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                FilterChip(
                  label: Text(
                    'Sadece ücretsiz (${ai.availableFreeModels.length})',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  selected: _onlyFree,
                  onSelected: (v) => setState(() => _onlyFree = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Ara: claude, free, gpt, gemini…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              '${filtered.length} model gösteriliyor — '
              'liste 6 saatte bir yenilenir.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              itemBuilder: (context, i) {
                final m = filtered[i];
                final selected = m.id == widget.currentModelId;
                return _LiveModelTile(
                  model: m,
                  selected: selected,
                  onTap: () {
                    context.read<AiSettingsProvider>().setModelId(m.id);
                    HapticFeedback.selectionClick();
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _LiveModelTile extends StatelessWidget {
  const _LiveModelTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final OpenRouterModel model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      dense: true,
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
              model.name.isEmpty ? model.id : model.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          if (model.isFree)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ÜCRETSİZ',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.purple.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else if (model.promptPricePerMillion != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                model.promptPricePerMillion!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${model.id} • ${(model.contextLength / 1000).toStringAsFixed(0)}K context',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

/// Aktif anahtar modunun durumunu gösteren bilgi/uyarı kartı.
/// 4 durum:
///   - builtIn + env var → yeşil "Pusula varsayılan anahtarı aktif"
///   - builtIn + env yok → kırmızı "Varsayılan anahtar yok, kendi anahtarına geç"
///   - userProvided + key var → mavi "Kişisel anahtar aktif"
///   - userProvided + key yok → turuncu "Anahtarını gir"
class _ApiKeyModeStatus extends StatelessWidget {
  const _ApiKeyModeStatus({
    required this.mode,
    required this.hasBuiltIn,
    required this.hasUserKey,
  });

  final ApiKeyMode mode;
  final bool hasBuiltIn;
  final bool hasUserKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, accent, text) = _resolve(cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _resolve(ColorScheme cs) {
    switch (mode) {
      case ApiKeyMode.builtIn:
        if (hasBuiltIn) {
          return (
            Icons.verified_outlined,
            Colors.green.shade700,
            'Varsayılan anahtar aktif — uygulama içi gömülü OpenRouter '
                'anahtarını kullanıyor. Senin için kullanım limiti '
                'paylaşılır.',
          );
        }
        return (
          Icons.warning_amber_rounded,
          Colors.red.shade700,
          'Bu sürümde varsayılan anahtar yok. "Kendi anahtarım" moduna '
              'geçip OpenRouter anahtarını gir.',
        );
      case ApiKeyMode.userProvided:
        if (hasUserKey) {
          return (
            Icons.person_outline,
            cs.primary,
            'Kişisel API anahtarın aktif — kendi rate-limit ve '
                'faturalandırman kullanılıyor.',
          );
        }
        return (
          Icons.error_outline,
          Colors.orange.shade700,
          'Anahtarın boş. Aşağıdaki kutuya OpenRouter anahtarını yapıştır '
              've "Kaydet"e bas.',
        );
    }
  }
}

class _AudioCacheTile extends StatefulWidget {
  const _AudioCacheTile();

  @override
  State<_AudioCacheTile> createState() => _AudioCacheTileState();
}

class _AudioCacheTileState extends State<_AudioCacheTile> {
  CacheStats? _stats;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final s = await BriefingAudioCache.stats();
    if (!mounted) return;
    setState(() => _stats = s);
  }

  Future<void> _clear() async {
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final removed = await BriefingAudioCache.clear();
    await _refreshStats();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('$removed adet ses dosyası silindi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final subtitle = s == null
        ? 'Yükleniyor…'
        : (s.count == 0
            ? 'Boş — henüz cache\'lenmiş ses yok.'
            : '${s.count} dosya · ${s.humanSize}');
    return ListTile(
      leading: const Icon(Icons.audiotrack_outlined),
      title: const Text('OpenAI TTS ses önbelleği'),
      subtitle: Text(subtitle),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (s == null || s.count == 0
              ? null
              : TextButton(
                  onPressed: _clear,
                  child: const Text('Temizle'),
                )),
    );
  }
}

class _SimpleRadioTile extends StatelessWidget {
  const _SimpleRadioTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, height: 1.35)),
    );
  }
}

class _TtsEngineTile extends StatelessWidget {
  const _TtsEngineTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final TtsEngineKind kind;
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
          Icon(
            kind == TtsEngineKind.system
                ? Icons.smartphone_outlined
                : Icons.cloud_outlined,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              kind.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      subtitle: Text(
        kind.description,
        style: const TextStyle(fontSize: 12, height: 1.35),
      ),
    );
  }
}
