import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../data/models/news_source.dart';
import '../../data/repositories/personalization_service.dart';
import '../../providers/keyword_filter_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shimmer_loading.dart';
import '../detail/article_detail_screen.dart';
import '../settings/keyword_filters_screen.dart';

/// "Sana Özel" — kullanıcının seçtiği kategori + kaynak + keyword
/// kombinasyonu ile filtrelenmiş haber akışı.
///
/// Varsayılan sıralama okuma geçmişinden çıkarılan ilgi profiline göredir
/// (`PersonalizationService`: zamanla sönümlenen ilgi + MMR çeşitlilik);
/// kullanıcı "En yeni"ye geçebilir.
///
/// Filtreler birleşim mantığında çalışır:
///   - Kategori boş ise: tüm seçili kategoriler
///   - Kaynak boş ise: tüm seçili kaynaklar (kullanıcı zaten onboarding'te
///     seçmiş olduklarından farklı bir alt küme seçmek isteyebilir)
///   - Keyword: KeywordFilterProvider listesi (config edilebilir)
///
/// Sonuç: NewsProvider'ın mevcut articles'ı üstüne LOCAL filtre. Live
/// veri için ayrı bir fetch yapmıyoruz — ana akış zaten live veriyi
/// taşıyor.
class PersonalizedFeedScreen extends StatefulWidget {
  const PersonalizedFeedScreen({super.key});

  @override
  State<PersonalizedFeedScreen> createState() =>
      _PersonalizedFeedScreenState();
}

class _PersonalizedFeedScreenState extends State<PersonalizedFeedScreen> {
  final Set<String> _selectedCategoryIds = <String>{};
  final Set<String> _selectedSourceIds = <String>{};

  /// Anahtar kelime filtresi de uygulansın mı? Aksi halde sadece
  /// kategori + kaynak filtresi çalışır.
  bool _applyKeywords = true;

  /// true: ilgi profiline göre sırala; false: en yeni üstte.
  bool _ranked = true;

  static const PersonalizationService _personalization =
      PersonalizationService();

  /// Katalog adı → id; `sourceId` taşımayan eski cache kayıtları için.
  static final Map<String, String> _sourceIdByName = {
    for (final s in NewsSourceCatalog.all) s.name: s.id,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final news = context.watch<NewsProvider>();
    final prefs = context.watch<PreferencesProvider>();
    final keywords = context.watch<KeywordFilterProvider>();
    final history = context.watch<ReadingHistoryProvider>();

    // Kullanıcının seçili kaynak listesi içinden filtrelenecek kaynak
    // alt-kümesi. Boş set → tüm seçili kaynaklar (yani NewsProvider'ın
    // gösterdiği her şey).
    final activeSources = prefs.effectiveSources;
    // Ana sayfada seçili kategoriden bağımsız olarak tüm haberler.
    final filtered = _applyFilters(
      news.articlesOf(NewsCategory.all.id),
      keywordProvider: keywords,
    );
    final List<RankedArticle> results;
    if (_ranked) {
      final profile = _personalization.buildProfile(history.entries);
      results = _personalization.rank(
        filtered,
        profile,
        readIds: history.ids.toSet(),
      );
    } else {
      results = [
        for (final a in List<Article>.of(filtered)
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt)))
          RankedArticle(a, 0),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sana Özel'),
        actions: [
          IconButton(
            tooltip: 'Anahtar kelimeler',
            icon: const Icon(Icons.tag),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const KeywordFiltersScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<NewsProvider>().refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Filtre özeti kartı ──
            SliverToBoxAdapter(
              child: _FilterSummaryCard(
                categoryCount: _selectedCategoryIds.length,
                sourceCount: _selectedSourceIds.length,
                keywordCount:
                    _applyKeywords ? keywords.count : 0,
                resultCount: filtered.length,
                onClear: () => setState(() {
                  _selectedCategoryIds.clear();
                  _selectedSourceIds.clear();
                }),
              ),
            ),

            // ── Sıralama ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text('Sana göre'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.schedule, size: 18),
                      label: Text('En yeni'),
                    ),
                  ],
                  selected: {_ranked},
                  onSelectionChanged: (v) =>
                      setState(() => _ranked = v.first),
                ),
              ),
            ),

            // ── Kategori chip'leri ──
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Kategoriler',
                subtitle: 'Filtreye dahil etmek için seç',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: NewsCategory.values.length - 1, // "all" hariç
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    // index 0 == NewsCategory.values[1] (skip 'all')
                    final c = NewsCategory.values[index + 1];
                    final selected = _selectedCategoryIds.contains(c.id);
                    return FilterChip(
                      label: Text(c.name),
                      avatar: Icon(c.icon, size: 16,
                          color: selected ? cs.onPrimary : c.color),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedCategoryIds.add(c.id);
                        } else {
                          _selectedCategoryIds.remove(c.id);
                        }
                      }),
                      selectedColor: c.color,
                      labelStyle: TextStyle(
                        color: selected ? cs.onPrimary : cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
            ),

            // ── Kaynak chip'leri ──
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Kaynaklar',
                subtitle: 'Sadece bu kaynaklardan',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: activeSources.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final s = activeSources[index];
                    final selected = _selectedSourceIds.contains(s.id);
                    return FilterChip(
                      label: Text(s.shortName),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedSourceIds.add(s.id);
                        } else {
                          _selectedSourceIds.remove(s.id);
                        }
                      }),
                      selectedColor: s.brandColor,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
            ),

            // ── Keyword toggle ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      const Icon(Icons.tag, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Anahtar kelimeler (${keywords.count})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                  subtitle: keywords.count == 0
                      ? const Text(
                          'Henüz kelime eklenmemiş — sağ üstten ekle',
                          style: TextStyle(fontSize: 12),
                        )
                      : Text(
                          keywords.keywords.take(3).join(', ') +
                              (keywords.count > 3
                                  ? ' …'
                                  : ''),
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  value: _applyKeywords && keywords.count > 0,
                  onChanged: keywords.count == 0
                      ? null
                      : (v) => setState(() => _applyKeywords = v),
                ),
              ),
            ),

            // ── Sonuç listesi ──
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Sonuçlar'),
            ),
            if (news.loading && filtered.isEmpty)
              SliverList.builder(
                itemCount: 4,
                itemBuilder: (_, _) => const ArticleCardSkeleton(),
              )
            else if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.tune,
                  title: 'Bu filtreyle eşleşen haber yok',
                  subtitle: 'Daha az filtre seç veya farklı kategoriler dene.',
                ),
              )
            else
              SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final r = results[index];
                  final a = r.article;
                  final card = ArticleCard(
                    article: a,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArticleDetailScreen(
                            article: a,
                            heroTag: 'personalized-img-${a.id}',
                          ),
                        ),
                      );
                    },
                  );
                  if (r.reason == null) return card;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_outlined,
                                size: 13, color: cs.primary),
                            const SizedBox(width: 5),
                            Text(
                              r.reason!,
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      card,
                    ],
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  List<Article> _applyFilters(
    List<Article> source, {
    required KeywordFilterProvider keywordProvider,
  }) {
    return source.where((a) {
      // Kategori filtresi (set boşsa atla = tümü dahil)
      if (_selectedCategoryIds.isNotEmpty &&
          !_selectedCategoryIds.contains(a.categoryId)) {
        return false;
      }
      // Kaynak filtresi
      if (_selectedSourceIds.isNotEmpty) {
        final id = a.sourceId.isNotEmpty
            ? a.sourceId
            : (_sourceIdByName[a.sourceName] ?? '');
        if (!_selectedSourceIds.contains(id)) return false;
      }
      // Keyword filtresi
      if (_applyKeywords && keywordProvider.hasKeywords) {
        if (!keywordProvider.matchesAny(a)) return false;
      }
      return true;
    }).toList(growable: false);
  }
}

class _FilterSummaryCard extends StatelessWidget {
  const _FilterSummaryCard({
    required this.categoryCount,
    required this.sourceCount,
    required this.keywordCount,
    required this.resultCount,
    required this.onClear,
  });

  final int categoryCount;
  final int sourceCount;
  final int keywordCount;
  final int resultCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFilters =
        categoryCount > 0 || sourceCount > 0 || keywordCount > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.12),
            cs.tertiary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list_rounded, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFilters
                      ? '$resultCount haber eşleşti'
                      : 'Filtre yok — tüm haberler',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                if (hasFilters)
                  Text(
                    [
                      if (categoryCount > 0) '$categoryCount kategori',
                      if (sourceCount > 0) '$sourceCount kaynak',
                      if (keywordCount > 0) '$keywordCount kelime',
                    ].join(' • '),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
          if (hasFilters)
            TextButton(
              onPressed: onClear,
              child: const Text('Temizle'),
            ),
        ],
      ),
    );
  }
}
