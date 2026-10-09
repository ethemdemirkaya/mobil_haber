import 'dart:isolate';
import 'dart:math' as math;

import '../../core/utils/turkish_text.dart';
import '../models/article.dart';

/// Çapraz Kaynak Haber Kümeleme — aynı olayı haber yapan farklı kaynakları
/// otomatik gruplar. Tamamen cihaz üzerinde çalışır, AI gerektirmez.
///
/// **Algoritma (v2):**
///   1. **Ön işleme:** Türkçe küçük harf + token'lara bölme + stop-word
///      süzme + F5 kök çıkarımı (`stemTr`): "seçimlerde" ⇔ "seçim".
///   2. **Ağırlıklandırma:** TF-IDF. Başlıktaki terimler ×2, cümle içinde
///      büyük harfle başlayan kelimeler (özel isim adayı) ×1.5. Her haberde
///      geçen "açıkladı" gibi terimler IDF ile bastırılır, "Galatasaray"
///      gibi ayırt edici terimler öne çıkar.
///   3. **Artımlı centroid kümeleme:** Haberler zaman sırasıyla işlenir; her
///      haber, zaman penceresi içindeki kümelerin **merkezine** (centroid)
///      kosinüs benzerliğiyle karşılaştırılır, eşiği geçen en yakın kümeye
///      katılır, yoksa yeni küme açar.
///
/// v1'deki Union-Find (single-linkage) A~B, B~C ⇒ A~C zincirlemesiyle
/// ilgisiz olayları tek dev kümede birleştirebiliyordu; centroid'e
/// karşılaştırma bunu önler.
///
/// **Karmaşıklık:** O(n·k) (k = aktif küme sayısı). Büyük listeler
/// [findClustersAsync] ile ayrı isolate'te hesaplanır, UI thread'i bloklanmaz.
///
/// **Not:** Eşik değeri ([threshold]) etiketli veriyle henüz kalibre
/// edilmedi; birim testlerdeki gerçekçi manşet örnekleriyle seçildi.
class NewsClusterService {
  const NewsClusterService({
    this.threshold = 0.28,
    this.timeWindow = const Duration(hours: 36),
    this.hotHalfLife = const Duration(hours: 6),
  });

  /// Bir haberin kümeye katılması için gereken minimum kosinüs benzerliği.
  final double threshold;

  /// Kümenin en yeni haberinden bu kadar uzak haberler katılamaz.
  final Duration timeWindow;

  /// Gündem skorunda her kaynağın katkısının yarıya indiği süre.
  final Duration hotHalfLife;

  static const int _minClusterSize = 2;

  /// Bu sayının altındaki listeler isolate maliyetine değmez.
  static const int _isolateThreshold = 80;

  /// [findClusters]'ın UI thread'ini bloklamayan sürümü.
  Future<List<NewsCluster>> findClustersAsync(
    List<Article> articles, {
    DateTime? now,
  }) {
    if (articles.length < _isolateThreshold) {
      return Future.value(findClusters(articles, now: now));
    }
    final list = List<Article>.of(articles, growable: false);
    final at = now ?? DateTime.now();
    return Isolate.run(() => findClusters(list, now: at));
  }

  /// Verilen makaleler arasında haber kümeleri tespit et. Her küme
  /// **farklı** kaynaklardan en az 2 başlık içerir. Sonuç gündem skoruna
  /// ([NewsCluster.hotScore]) göre azalan sıralıdır.
  List<NewsCluster> findClusters(List<Article> articles, {DateTime? now}) {
    if (articles.length < 2) return const [];
    final at = now ?? DateTime.now();

    final vectors = _vectorize(articles);
    final order = List<int>.generate(articles.length, (i) => i)
      ..sort((a, b) =>
          articles[a].publishedAt.compareTo(articles[b].publishedAt));

    final building = <_ClusterBuilder>[];
    for (final i in order) {
      final v = vectors[i];
      if (v.isEmpty) continue;
      final a = articles[i];
      _ClusterBuilder? best;
      var bestSim = threshold;
      for (final c in building) {
        if (a.publishedAt.difference(c.latest).abs() > timeWindow) continue;
        final sim = c.similarity(v);
        if (sim >= bestSim) {
          bestSim = sim;
          best = c;
        }
      }
      if (best != null) {
        best.add(a, v);
      } else {
        building.add(_ClusterBuilder(a, v));
      }
    }

    final clusters = <NewsCluster>[];
    for (final c in building) {
      if (c.members.length < _minClusterSize) continue;
      // Aynı kaynaktan birden fazla varsa en yenisini al (takip haberi,
      // güncellenmiş başlık vb.). Küme farklı bakış açılarını gösterir.
      final unique = <String, Article>{};
      for (final a in c.members) {
        final key = a.sourceName.isEmpty ? a.id : a.sourceName;
        final existing = unique[key];
        if (existing == null || a.publishedAt.isAfter(existing.publishedAt)) {
          unique[key] = a;
        }
      }
      if (unique.length < _minClusterSize) continue;
      final members = unique.values.toList(growable: false)
        ..sort((x, y) => y.publishedAt.compareTo(x.publishedAt));
      clusters.add(NewsCluster(
        id: 'cluster_${members.last.id}',
        articles: members,
        hotScore: _hotScore(members, at),
      ));
    }

    clusters.sort((a, b) {
      final byScore = b.hotScore.compareTo(a.hotScore);
      if (byScore != 0) return byScore;
      return b.latestAt.compareTo(a.latestAt);
    });
    return clusters;
  }

  /// Her bağımsız kaynak 1 puanla başlar ve [hotHalfLife] sürede yarıya
  /// iner. 2 kaynak az önce yayınladıysa ≈2; 3 kaynak 6 saat önce
  /// yayınladıysa ≈1.5. Böylece hem kaynak sayısı hem tazelik ölçülür.
  double _hotScore(List<Article> members, DateTime now) {
    final halfLifeH = hotHalfLife.inMinutes / 60.0;
    var score = 0.0;
    for (final a in members) {
      final ageH = math.max(0, now.difference(a.publishedAt).inMinutes) / 60.0;
      score += math.pow(0.5, ageH / halfLifeH);
    }
    return score;
  }

  /// Her makale için L2-normalize edilmiş TF-IDF vektörü.
  List<Map<String, double>> _vectorize(List<Article> articles) {
    final tfs = articles.map(_termFrequencies).toList(growable: false);
    final df = <String, int>{};
    for (final tf in tfs) {
      for (final term in tf.keys) {
        df[term] = (df[term] ?? 0) + 1;
      }
    }
    final n = articles.length;
    return tfs.map((tf) {
      final v = <String, double>{};
      var norm = 0.0;
      tf.forEach((term, f) {
        final idf = math.log((n + 1) / (df[term]! + 1)) + 1;
        final w = f * idf;
        v[term] = w;
        norm += w * w;
      });
      if (norm == 0) return v;
      final inv = 1 / math.sqrt(norm);
      v.updateAll((_, w) => w * inv);
      return v;
    }).toList(growable: false);
  }

  Map<String, double> _termFrequencies(Article a) {
    final tf = <String, double>{};
    void addText(String text, double baseWeight) {
      final words = text.split(RegExp(r'\s+'));
      for (var i = 0; i < words.length; i++) {
        // "Erdoğan'ın" → "Erdoğan": kesmeden sonraki ek ayrı token olmasın.
        final w = words[i].split(_apostrophe).first;
        if (w.isEmpty) continue;
        final first = w[0];
        final properNoun = i > 0 &&
            first != first.toLowerCase() &&
            first == first.toUpperCase();
        for (final t in trTokens(w)) {
          if (t.length < 3 || trNewsStopWords.contains(t)) continue;
          final stem = stemTr(t);
          tf[stem] = (tf[stem] ?? 0) + baseWeight * (properNoun ? 1.5 : 1);
        }
      }
    }

    addText(a.title, 2);
    addText(a.summary, 1);
    return tf;
  }

  static final RegExp _apostrophe = RegExp("['’‘`]");
}

class _ClusterBuilder {
  _ClusterBuilder(Article first, Map<String, double> v)
      : members = [first],
        latest = first.publishedAt {
    _addVector(v);
  }

  final List<Article> members;
  DateTime latest;
  final Map<String, double> _sum = <String, double>{};
  double _norm = 0;

  void add(Article a, Map<String, double> v) {
    members.add(a);
    if (a.publishedAt.isAfter(latest)) latest = a.publishedAt;
    _addVector(v);
  }

  void _addVector(Map<String, double> v) {
    v.forEach((k, w) => _sum[k] = (_sum[k] ?? 0) + w);
    var sq = 0.0;
    for (final w in _sum.values) {
      sq += w * w;
    }
    _norm = math.sqrt(sq);
  }

  /// [v] (birim vektör) ile küme merkezi arasındaki kosinüs benzerliği.
  double similarity(Map<String, double> v) {
    if (_norm == 0) return 0;
    var dot = 0.0;
    v.forEach((k, w) {
      final s = _sum[k];
      if (s != null) dot += w * s;
    });
    return dot / _norm;
  }
}

/// Bir haber kümesi — aynı olayı haber yapan farklı kaynakların
/// makaleleri. UI bunu "ortak başlık + manşet karşılaştırma" olarak
/// gösterir.
class NewsCluster {
  const NewsCluster({
    required this.id,
    required this.articles,
    this.hotScore = 0,
  });

  final String id;

  /// Kaynak başına en yeni haber, yeniden eskiye sıralı.
  final List<Article> articles;

  /// Zamanla sönümlenen gündem skoru (bkz. `NewsClusterService._hotScore`).
  final double hotScore;

  /// Bu olayı haberleştiren ayrık kaynak sayısı.
  int get sourceCount {
    final names = <String>{};
    for (final a in articles) {
      if (a.sourceName.isNotEmpty) names.add(a.sourceName);
    }
    return names.isEmpty ? articles.length : names.length;
  }

  /// Cluster içindeki en yeni makalenin tarihi.
  DateTime get latestAt {
    DateTime latest = articles.first.publishedAt;
    for (final a in articles) {
      if (a.publishedAt.isAfter(latest)) latest = a.publishedAt;
    }
    return latest;
  }

  /// Kümeyi temsil eden başlık — en yeni makalenin başlığı.
  String get headline {
    final newest = articles.reduce(
      (a, b) => a.publishedAt.isAfter(b.publishedAt) ? a : b,
    );
    return newest.title;
  }

  /// Cluster'da temsil edilen kategori — çoğunluk oylaması.
  String get dominantCategoryId {
    final tally = <String, int>{};
    for (final a in articles) {
      tally[a.categoryId] = (tally[a.categoryId] ?? 0) + 1;
    }
    final entries = tally.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }
}
