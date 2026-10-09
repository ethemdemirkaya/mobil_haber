import 'package:pusula_news/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tts/briefing_audio_cache.dart';
import '../../data/repositories/elevenlabs_tts_service.dart';
import '../../data/repositories/openai_tts_service.dart';
import '../../data/repositories/openrouter_models_repository.dart';
import '../../providers/ai_settings_provider.dart';
import '../../providers/tts_settings_provider.dart';

part 'widgets/model_selection.dart';
part 'widgets/settings_tiles.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final TextEditingController _keyController;
  late final TextEditingController _customModelController;
  late final TextEditingController _openaiTtsKeyController;
  late final TextEditingController _elTtsKeyController;
  bool _obscureKey = true;
  bool _obscureTtsKey = true;
  bool _obscureElTtsKey = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final ai = context.read<AiSettingsProvider>();
    _keyController = TextEditingController(text: ai.apiKey);
    final isPreset = AiSettingsProvider.presets.any((p) => p.id == ai.modelId);
    _customModelController = TextEditingController(
      text: isPreset ? '' : ai.modelId,
    );
    final tts = context.read<TtsSettingsProvider>();
    _openaiTtsKeyController = TextEditingController(text: tts.openaiTtsKey);
    _elTtsKeyController = TextEditingController(text: tts.elevenLabsApiKey);

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
    _elTtsKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    HapticFeedback.selectionClick();
    final ai = context.read<AiSettingsProvider>();
    await ai.setApiKey(_keyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('API anahtarı kaydedildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      ..showSnackBar(
        SnackBar(
          content: Text('Model güncellendi: $v'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _saveTtsKey() async {
    HapticFeedback.selectionClick();
    final tts = context.read<TtsSettingsProvider>();
    await tts.setOpenaiTtsKey(_openaiTtsKeyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('OpenAI TTS anahtarı kaydedildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _saveElTtsKey() async {
    HapticFeedback.selectionClick();
    final tts = context.read<TtsSettingsProvider>();
    await tts.setElevenLabsApiKey(_elTtsKeyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('ElevenLabs API anahtarı kaydedildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openElevenLabsPage() async {
    final uri = Uri.parse('https://elevenlabs.io/app/settings/api-keys');
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

  Future<void> _test() async {
    final ai = context.read<AiSettingsProvider>();
    if (ai.apiKey.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Önce API anahtarı girin.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    setState(() => _testing = true);
    HapticFeedback.selectionClick();
    final result = await ai.testConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
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
    final tts = context.watch<TtsSettingsProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Yapay Zeka Özetleme')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ─────────── Etkin/Pasif ───────────
          SwitchListTile(
            secondary: const Icon(AppIcons.sparkles),
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
                      icon: Icon(AppIcons.shieldCheck, size: 16),
                      label: Text('Varsayılan'),
                    ),
                    ButtonSegment(
                      value: ApiKeyMode.userProvided,
                      icon: Icon(AppIcons.user, size: 16),
                      label: Text('Kendi anahtarım'),
                    ),
                  ],
                  selected: {ai.apiKeyMode},
                  onSelectionChanged: (set) {
                    HapticFeedback.selectionClick();
                    context.read<AiSettingsProvider>().setApiKeyMode(set.first);
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
                      Icon(AppIcons.cloud, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Sağlayıcı: OpenRouter',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
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
                      icon: const Icon(AppIcons.externalLink, size: 14),
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
                  prefixIcon: const Icon(AppIcons.key),
                  suffixIcon: IconButton(
                    tooltip: _obscureKey ? 'Göster' : 'Gizle',
                    icon: Icon(_obscureKey ? AppIcons.eye : AppIcons.eyeOff),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
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
                    icon: const Icon(AppIcons.deviceFloppy, size: 18),
                    label: const Text('Kaydet'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.bolt, size: 18),
                    label: Text(
                      _testing ? 'Test ediliyor' : 'Bağlantıyı test et',
                    ),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.bolt, size: 18),
                    label: Text(
                      _testing
                          ? 'Test ediliyor'
                          : 'Varsayılan anahtarı test et',
                    ),
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
                    Icon(
                      AppIcons.alertCircle,
                      size: 18,
                      color: cs.onErrorContainer,
                    ),
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
                      icon: const Icon(AppIcons.x, size: 16),
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
              onTap: () => context.read<AiSettingsProvider>().setModelId(p.id),
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
                prefixIcon: const Icon(AppIcons.code),
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
                icon: const Icon(AppIcons.check, size: 18),
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
              selected: tts.ttsEngine == kind,
              onTap: () =>
                  context.read<TtsSettingsProvider>().setTtsEngine(kind),
            ),
          if (tts.ttsEngine == TtsEngineKind.openai) ...[
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
                        Icon(AppIcons.infoCircle, size: 16, color: cs.primary),
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
                  prefixIcon: const Icon(AppIcons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureTtsKey ? AppIcons.eye : AppIcons.eyeOff),
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
                  icon: const Icon(AppIcons.deviceFloppy, size: 18),
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
                selected: tts.openaiTtsVoice == v.id,
                onTap: () =>
                    context.read<TtsSettingsProvider>().setOpenaiTtsVoice(v.id),
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
                selected: tts.openaiTtsModel == m.id,
                onTap: () =>
                    context.read<TtsSettingsProvider>().setOpenaiTtsModel(m.id),
              ),
            const SizedBox(height: 12),
          ],
          // ─────────── ElevenLabs TTS yapılandırması ───────────
          if (tts.ttsEngine == TtsEngineKind.elevenlabs) ...[
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
                        Icon(AppIcons.waveSine, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'ElevenLabs TTS yapılandırması',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Son derece doğal ses kalitesi. Multilingual v2 ile '
                      'Türkçe dahil 29 dil. Anahtar '
                      'elevenlabs.io/app/settings/api-keys adresinden alınır.',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
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
                        onPressed: _openElevenLabsPage,
                        icon: const Icon(AppIcons.externalLink, size: 14),
                        label: const Text('ElevenLabs API anahtarı al'),
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
                controller: _elTtsKeyController,
                obscureText: _obscureElTtsKey,
                decoration: InputDecoration(
                  labelText: 'ElevenLabs API anahtarı',
                  hintText: 'sk_...',
                  prefixIcon: const Icon(AppIcons.key),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureElTtsKey ? AppIcons.eye : AppIcons.eyeOff,
                    ),
                    onPressed: () =>
                        setState(() => _obscureElTtsKey = !_obscureElTtsKey),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _saveElTtsKey(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _saveElTtsKey,
                  icon: const Icon(AppIcons.deviceFloppy, size: 18),
                  label: const Text('ElevenLabs anahtarını kaydet'),
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
            for (final v in ElevenLabsTtsService.voices)
              _SimpleRadioTile(
                title: v.label,
                subtitle: v.description,
                selected: tts.elevenLabsVoiceId == v.id,
                onTap: () => context
                    .read<TtsSettingsProvider>()
                    .setElevenLabsVoiceId(v.id),
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
            for (final m in ElevenLabsTtsService.models)
              _SimpleRadioTile(
                title: m.label,
                subtitle: m.description,
                selected: tts.elevenLabsModelId == m.id,
                onTap: () => context
                    .read<TtsSettingsProvider>()
                    .setElevenLabsModelId(m.id),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                'Ses sabitliği (Stability)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(AppIcons.waveSine, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    tts.elevenLabsStability.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: tts.elevenLabsStability,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (v) => context
                          .read<TtsSettingsProvider>()
                          .setElevenLabsStability(v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                'Düşük = daha dramatik, değişken. Yüksek = tutarlı, sakin.',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                'Ses benzerliği (Similarity Boost)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(AppIcons.user, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    tts.elevenLabsSimilarityBoost.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: tts.elevenLabsSimilarityBoost,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (v) => context
                          .read<TtsSettingsProvider>()
                          .setElevenLabsSimilarityBoost(v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                'Yüksek = sesin orijinaline sadık, düşük = daha esnek.',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),

          // ─────────── Cache yönetimi ───────────
          const _SectionTitle('Önbellek'),
          ListTile(
            leading: const Icon(AppIcons.brush),
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
