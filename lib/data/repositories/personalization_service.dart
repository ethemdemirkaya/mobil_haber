import 'dart:math' as math;

import '../../core/utils/turkish_text.dart';
import '../local/reading_history_store.dart';
import '../models/article.dart';
import '../models/category.dart';

/// Okuma geçmişinden çıkarılan ilgi profili. Tamamen cihazda hesaplanır,
/// hiçbir yere gönderilmez.
class InterestProfile {
  const InterestProfile({
    this.categories = const {},
    this.sources = const {},
    this.terms = const {},
    this.signalCount = 0,
  });

  static const InterestProfile empty = InterestProfile();

  /// Kategori id → ağırlık (en yüksek = 1).
  final Map<String, double> categories;

  /// Kaynak adı → ağırlık (en yüksek = 1).
  final Map<String, double> sources;

  /// Kök terim → ağırlık (L2 normalize).
  final Map<String, double> terms;

  /// Profile katkı veren okuma sayısı.
  final int signalCount;

  bool get isEmpty => signalCount == 0;
}

/// Bir önerinin skoru ve kullanıcıya gösterilecek kısa gerekçesi.
class RankedArticle {
  const RankedArticle(this.article, this.score, {this.reason});

  final Article article;
  final double score;

  /// "Spor haberlerini sık okuyorsun" gibi; soğuk başlangıçta null.
  final String? reason;
}

/// Cihaz üzerinde içerik tabanlı öneri + çeşitlilik bilinçli sıralama.
///
/// **İlgi profili:** Her okuma, okunma zamanına göre sönümlenen bir ağırlıkla
/// (yarı ömür [historyHalfLife]) kategori, kaynak ve başlık terimlerine
/// katkı verir. Eski ilgi alanları zamanla etkisini kaybeder.
///
/// **Alaka skoru:** kategori uyumu, kaynak uyumu, terim kosinüsü ve tazelik
/// ağırlıklı toplamı. Daha önce okunan haberler geriye itilir.
///
/// **Çeşitlilik (MMR):** Sadece alakaya göre sıralamak akışı tek kategori ve
/// tek kaynağa kilitler (filtre balonu). Maximal Marginal Relevance ile her
/// adımda `λ·alaka − (1−λ)·zaten seçilenlere benzerlik` en yüksek olan
/// haber seçilir; benzerlik aynı kategori/kaynak ve ortak terimlerden
/// hesaplanır.
class PersonalizationService {
  const PersonalizationService({
    this.historyHalfLife = const Duration(days: 7),
    this.freshnessHalfLife = const Duration(hours: 12),
    this.lambda = 0.5,
    this.mmrWindow = 60,
  });

  final Duration historyHalfLife;
  final Duration freshnessHalfLife;

  /// MMR alaka/çeşitlilik dengesi: 1 = yalnızca alaka, 0 = yalnızca
  /// çeşitlilik.
  final double lambda;

  /// MMR yalnızca en alakalı bu kadar haber üzerinde çalışır (O(k²));
  /// kalanlar alaka sırasıyla eklenir.
  final int mmrWindow;

  static const double _wCategory = 0.35;
  static const double _wSource = 0.20;
  static const double _wTerms = 0.30;
  static const double _wFresh = 0.15;
  static const double _readPenalty = 0.3;

  InterestProfile buildProfile(List<HistoryEntry> history, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final halfLifeDays = historyHalfLife.inHours / 24.0;
    final categories = <String, double>{};
    final sources = <String, double>{};
    final terms = <String, double>{};
    var signals = 0;

    for (final entry in history) {
      final a = entry.article;
      if (a == null) continue;
      final ageDays =
          math.max(0, at.difference(entry.readAt).inMinutes) / 1440.0;
      final w = math.pow(0.5, ageDays / halfLifeDays).toDouble();
      signals++;
      categories[a.categoryId] = (categories[a.categoryId] ?? 0) + w;
      if (a.sourceName.isNotEmpty) {
        sources[a.sourceName] = (sources[a.sourceName] ?? 0) + w;
      }
      for (final t in _terms(a.title)) {
        terms[t] = (terms[t] ?? 0) + w;
      }
    }

    return InterestProfile(
      categories: _scaleToMax(categories),
      sources: _scaleToMax(sources),
      terms: _l2(terms),
      signalCount: signals,
    );
  }

  /// [candidates]'ı profile göre sıralar. Profil boşsa tazelik sırası ve
  /// yine de çeşitlilik uygulanır.
  List<RankedArticle> rank(
    List<Article> candidates,
    InterestProfile profile, {
    Set<String> readIds = const {},
    DateTime? now,
  }) {
    if (candidates.isEmpty) return const [];
    final at = now ?? DateTime.now();
    final freshH = freshnessHalfLife.inMinutes / 60.0;

    final scored = <_Scored>[];
    for (final a in candidates) {
      final termVec = _l2({for (final t in _terms(a.title)) t: 1.0});
      final ageH = math.max(0, at.difference(a.publishedAt).inMinutes) / 60.0;
      final fresh = math.pow(0.5, ageH / freshH).toDouble();

      double score;
      String? reason;
      if (profile.isEmpty) {
        score = fresh;
      } else {
        final cat = profile.categories[a.categoryId] ?? 0;
        final src = profile.sources[a.sourceName] ?? 0;
        var cos = 0.0;
        termVec.forEach((t, w) => cos += w * (profile.terms[t] ?? 0));
        score = _wCategory * cat +
            _wSource * src +
            _wTerms * cos +
            _wFresh * fresh;
        reason = _reason(a, cat: cat, src: src, cos: cos);
      }
      if (readIds.contains(a.id)) score *= _readPenalty;
      scored.add(_Scored(a, score, termVec, reason));
    }
    scored.sort((x, y) => y.score.compareTo(x.score));

    final window = scored.take(mmrWindow).toList();
    final rest = scored.skip(mmrWindow);
    final selected = <_Scored>[];
    final maxScore = window.first.score <= 0 ? 1.0 : window.first.score;
    while (window.isNotEmpty) {
      var bestIdx = 0;
      var bestVal = double.negativeInfinity;
      for (var i = 0; i < window.length; i++) {
        final c = window[i];
        var maxSim = 0.0;
        for (final s in selected) {
          final sim = _similarity(c, s);
          if (sim > maxSim) maxSim = sim;
        }
        final val = lambda * (c.score / maxScore) - (1 - lambda) * maxSim;
        if (val > bestVal) {
          bestVal = val;
          bestIdx = i;
        }
      }
      selected.add(window.removeAt(bestIdx));
    }

    return [
      for (final s in [...selected, ...rest])
        RankedArticle(s.article, s.score, reason: s.reason),
    ];
  }

  /// İki haber arası kaba benzerlik (0..1). Ağırlığın yarısı başlık
  /// terimlerinde: aynı kategoriden *farklı* olaylar birbirini fazla itmez,
  /// aynı olayın kopyaları ve aynı kaynak+kategori tekrarları itilir.
  double _similarity(_Scored a, _Scored b) {
    var cos = 0.0;
    final small = a.terms.length <= b.terms.length ? a.terms : b.terms;
    final large = identical(small, a.terms) ? b.terms : a.terms;
    small.forEach((t, w) => cos += w * (large[t] ?? 0));
    final sameCat = a.article.categoryId == b.article.categoryId ? 1.0 : 0.0;
    final sameSrc = a.article.sourceName.isNotEmpty &&
            a.article.sourceName == b.article.sourceName
        ? 1.0
        : 0.0;
    return 0.3 * sameCat + 0.2 * sameSrc + 0.5 * cos;
  }

  String? _reason(Article a,
      {required double cat, required double src, required double cos}) {
    final catPart = _wCategory * cat;
    final srcPart = _wSource * src;
    final termPart = _wTerms * cos;
    final best = math.max(catPart, math.max(srcPart, termPart));
    if (best < 0.1) return null;
    if (best == termPart) return 'Okuduğun konulara benziyor';
    if (best == catPart) {
      return '${NewsCategory.byId(a.categoryId).name} haberlerini sık '
          'okuyorsun';
    }
    return '${a.sourceName} kaynağını sık okuyorsun';
  }

  Iterable<String> _terms(String text) => trTokens(text)
      .where((t) => t.length >= 3 && !trNewsStopWords.contains(t))
      .map(stemTr)
      .toSet();

  static Map<String, double> _scaleToMax(Map<String, double> m) {
    if (m.isEmpty) return const {};
    final max = m.values.reduce(math.max);
    return {for (final e in m.entries) e.key: e.value / max};
  }

  static Map<String, double> _l2(Map<String, double> m) {
    if (m.isEmpty) return const {};
    var sq = 0.0;
    for (final v in m.values) {
      sq += v * v;
    }
    final inv = 1 / math.sqrt(sq);
    return {for (final e in m.entries) e.key: e.value * inv};
  }
}

class _Scored {
  _Scored(this.article, this.score, this.terms, this.reason);

  final Article article;
  final double score;
  final Map<String, double> terms;
  final String? reason;
}
