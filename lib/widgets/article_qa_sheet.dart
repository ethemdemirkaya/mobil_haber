import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/article.dart';
import '../providers/ai_settings_provider.dart';

/// Detail screen'den açılan AI Haber Asistanı bottom sheet.
///
/// Kullanıcı bir hazır soru ya da serbest soru girer; AI sadece haber
/// metnine dayalı cevap verir. Mevcut OpenRouter altyapısı kullanılır.
class ArticleQaSheet extends StatefulWidget {
  const ArticleQaSheet({super.key, required this.article});

  final Article article;

  static Future<void> show(BuildContext context, Article article) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ArticleQaSheet(article: article),
    );
  }

  @override
  State<ArticleQaSheet> createState() => _ArticleQaSheetState();
}

class _ArticleQaSheetState extends State<ArticleQaSheet> {
  final TextEditingController _input = TextEditingController();
  final List<_QaTurn> _turns = [];

  static const List<String> _suggested = [
    'Kısa özet ver (2 cümle)',
    'Bu haber neden önemli?',
    'Çocuklara nasıl anlatırsın?',
    'Olayın arkaplanı nedir?',
    'Sayıları ve tarihleri listele',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    final ai = context.read<AiSettingsProvider>();
    if (!ai.isReady()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI kapalı — Ayarlar > Yapay Zeka'),
        ),
      );
      return;
    }
    setState(() {
      _turns.add(_QaTurn(question: question, answer: null, loading: true));
      _input.clear();
    });
    final answer = await ai.askQuestion(widget.article, question);
    if (!mounted) return;
    setState(() {
      final last = _turns.last;
      _turns[_turns.length - 1] = _QaTurn(
        question: last.question,
        answer: answer ?? ai.lastError ?? 'Cevap alınamadı',
        loading: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ai = context.watch<AiSettingsProvider>();
    final loading = ai.loadingQaId == widget.article.id;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.psychology_alt, color: cs.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Haber Asistanı',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Bu haber hakkında soru sor — sadece metne dayanır',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  children: [
                    if (_turns.isEmpty)
                      _SuggestedPrompts(
                        suggested: _suggested,
                        onTap: _ask,
                      ),
                    for (final t in _turns)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _QaTurnView(turn: t),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'Haberle ilgili soru…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty && !loading) _ask(v.trim());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: loading
                          ? null
                          : () {
                              final q = _input.text.trim();
                              if (q.isNotEmpty) _ask(q);
                            },
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedPrompts extends StatelessWidget {
  const _SuggestedPrompts({required this.suggested, required this.onTap});

  final List<String> suggested;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HIZLI SORULAR',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in suggested)
              ActionChip(
                label: Text(s),
                onPressed: () => onTap(s),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI sadece bu haberin metnine dayanır; metinde yoksa '
                  '"bilgi yok" der. Spekülasyon yapmaz.',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QaTurn {
  const _QaTurn({
    required this.question,
    required this.answer,
    required this.loading,
  });

  final String question;
  final String? answer;
  final bool loading;
}

class _QaTurnView extends StatelessWidget {
  const _QaTurnView({required this.turn});

  final _QaTurn turn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Soru
        Container(
          margin: const EdgeInsets.only(left: 32, bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.14),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            turn.question,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              height: 1.35,
            ),
          ),
        ),
        // Cevap
        Container(
          margin: const EdgeInsets.only(right: 32),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: turn.loading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Yanıt hazırlanıyor…',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : Text(
                  turn.answer ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface,
                    height: 1.5,
                  ),
                ),
        ),
      ],
    );
  }
}
