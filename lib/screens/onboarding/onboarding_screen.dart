import 'package:pusula_news/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/category.dart';
import '../../providers/preferences_provider.dart';
import '../../widgets/pusula_glyph.dart';
import 'source_picker_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _choosing = false;
  bool _saving = false;
  final Set<String> _interests = {};
  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    await context.read<PreferencesProvider>().setInterests(_interests);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SourcePickerScreen()));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                children: [
                  const PusulaGlyph(size: 30, showRim: false),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Pusula',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ),
                  if (_choosing)
                    TextButton(
                      onPressed: _saving ? null : _continue,
                      child: const Text('Atla'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _choosing ? _topics(theme) : _welcome(theme),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () {
                            if (_choosing) {
                              _continue();
                            } else {
                              setState(() => _choosing = true);
                            }
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _choosing ? 'Kaynaklarını seç' : 'Başlayalım',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(AppIcons.arrowForward, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _choosing
                        ? 'Tercihlerini daha sonra değiştirebilirsin.'
                        : 'Farklı kaynaklar. Daha geniş bir bakış.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome(ThemeData theme) => Column(
    key: const ValueKey('welcome'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'GÜRÜLTÜ AZALSIN, BAKIŞIN GENİŞLESİN.',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Haberlerde\nyönünü bul.',
        style: theme.textTheme.displayMedium?.copyWith(
          letterSpacing: -1.5,
          height: 1.03,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'Gündemi farklı kaynaklardan takip et.\nMerak ettiğini oku, vaktin yoksa dinle.',
        style: theme.textTheme.bodyLarge,
      ),
      const SizedBox(height: 20),
      Center(
        child: Image.asset(
          'assets/brand/wise-owl.png',
          height: 230,
          semanticLabel: 'Gazete okuyan gözlüklü bilge baykuş',
        ),
      ),
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.article, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bir olay, farklı bakışlar.',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Çapraz Bakış ile aynı haberi farklı kaynaklardan karşılaştır.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
  Widget _topics(ThemeData theme) => Column(
    key: const ValueKey('interests'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'SENİN PUSULAN',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 16),
      Text('Neyi merak\nediyorsun?', style: theme.textTheme.displaySmall),
      const SizedBox(height: 12),
      Text(
        'İlgilendiğin konuları seç. Senin İçin akışını bu konularla başlatalım.',
        style: theme.textTheme.bodyLarge,
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 10,
        runSpacing: 12,
        children: [
          for (final c in NewsCategory.values.where((c) => c.id != 'all'))
            FilterChip(
              avatar: Icon(c.icon, size: 18),
              label: Text(c.name),
              selected: _interests.contains(c.id),
              onSelected: (selected) => setState(() {
                if (selected) {
                  _interests.add(c.id);
                } else {
                  _interests.remove(c.id);
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: 28),
      Text(
        _interests.isEmpty
            ? 'Seçim yapmazsan tüm konuları görebilirsin.'
            : '${_interests.length} konu seçtin.',
        style: theme.textTheme.bodySmall,
      ),
      TextButton.icon(
        onPressed: () => setState(() => _choosing = false),
        icon: const Icon(AppIcons.arrowLeft, size: 16),
        label: const Text('Geri'),
      ),
    ],
  );
}
