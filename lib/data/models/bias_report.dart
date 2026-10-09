/// AI tarafından üretilen bir manşet/yazı yönlülük raporu.
///
/// **Skor 0-100 arası:**
///   - 0-25: Nötr (objektif dil, kanıt odaklı)
///   - 26-50: Hafif yönlü (duygusal kelimeler, tek perspektif)
///   - 51-75: Belirgin yönlü (yorum yüklü manşet, tarafları temsil etmez)
///   - 76-100: Yüksek yönlü (propaganda dili, sadece bir taraf)
///
/// Skor LLM tarafından metnin **dil özelliklerine göre** üretilir, içeriğin
/// olgu doğruluğuna göre değil — bias detection ≠ fact checking.
///
/// LLM skoru tekrar üretilebilir ve kalibre bir ölçüm değildir. Bu yüzden
/// yanında cihaz üzerinde, kural tabanlı bağımsız bir ölçüm
/// ([lexicalScore]) tutulur ve ikisinin uyumuna göre [confidence] verilir.
/// UI kesin bir sayı yerine bant + güven düzeyi gösterir.
class BiasReport {
  const BiasReport({
    required this.score,
    required this.label,
    required this.cues,
    required this.summary,
    this.lexicalScore,
    this.lexicalCues = const [],
    this.confidence = BiasConfidence.low,
  });

  /// 0-100 arası bias skoru.
  final int score;

  /// İnsan-okuyabilir kategori: "Nötr", "Hafif yönlü", "Belirgin yönlü",
  /// "Yüksek yönlü".
  final String label;

  /// Modelin tespit ettiği ve **metinde birebir geçtiği doğrulanan**
  /// ifadeler (max 5). Metinde bulunmayan "alıntılar" atılır.
  final List<String> cues;

  /// Kural tabanlı dil sinyali skoru (0-100); eski kayıtlarda null.
  final int? lexicalScore;

  /// Kural tabanlı analizörün bulduğu ifadeler.
  final List<String> lexicalCues;

  /// LLM ve kural tabanlı ölçümün uyumuna dayalı güven düzeyi.
  final BiasConfidence confidence;

  /// 1-2 cümlelik açıklama: "Manşet 'çıkmaza saplandı' gibi yorum
  /// içeren kelimeler kullanmış" gibi.
  final String summary;

  /// Skoru renk için 4 banta indirger (UI tarafında renge map'lenir).
  BiasBand get band => bandOf(score);

  static BiasBand bandOf(int score) {
    if (score <= 25) return BiasBand.neutral;
    if (score <= 50) return BiasBand.mild;
    if (score <= 75) return BiasBand.notable;
    return BiasBand.heavy;
  }

  /// Kullanıcıya gösterilecek, tekrarsız ifade listesi.
  List<String> get allCues {
    final seen = <String>{};
    return [
      for (final c in [...cues, ...lexicalCues])
        if (seen.add(c.toLowerCase())) c,
    ];
  }

  /// İki ölçümün ve doğrulanan alıntıların uyumundan güven düzeyi.
  ///
  /// - **Yüksek:** LLM ve kural tabanlı bant aynı, ve model ifade
  ///   gösterdiyse en az yarısı metinde gerçekten geçiyor.
  /// - **Orta:** bantlar komşu ya da yalnızca biri sağlanıyor.
  /// - **Düşük:** bantlar uzak ve alıntılar doğrulanamıyor.
  static BiasConfidence assessConfidence({
    required int llmScore,
    required int lexicalScore,
    required int claimedCues,
    required int verifiedCues,
  }) {
    final bandGap =
        (bandOf(llmScore).index - bandOf(lexicalScore).index).abs();
    final cuesOk = claimedCues == 0
        ? llmScore <= 25
        : verifiedCues * 2 >= claimedCues;
    if (bandGap == 0 && cuesOk) return BiasConfidence.high;
    if (bandGap <= 1 && (cuesOk || bandGap == 0)) return BiasConfidence.medium;
    return BiasConfidence.low;
  }

  Map<String, Object?> toJson() => {
        'score': score,
        'label': label,
        'cues': cues,
        'summary': summary,
        'lexicalScore': lexicalScore,
        'lexicalCues': lexicalCues,
        'confidence': confidence.name,
      };

  static BiasReport? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final score = (raw['score'] as num?)?.toInt();
    final label = raw['label']?.toString();
    final summary = raw['summary']?.toString();
    final cuesRaw = raw['cues'];
    if (score == null || label == null || summary == null) return null;
    final cues = <String>[];
    if (cuesRaw is List) {
      for (final c in cuesRaw) {
        final s = c?.toString().trim() ?? '';
        if (s.isNotEmpty) cues.add(s);
      }
    }
    final lexicalRaw = raw['lexicalCues'];
    return BiasReport(
      score: score.clamp(0, 100),
      label: label,
      cues: cues.take(5).toList(growable: false),
      summary: summary,
      lexicalScore: (raw['lexicalScore'] as num?)?.toInt(),
      lexicalCues: lexicalRaw is List
          ? lexicalRaw.map((e) => e.toString()).toList(growable: false)
          : const [],
      confidence: BiasConfidence.values.firstWhere(
        (c) => c.name == raw['confidence'],
        orElse: () => BiasConfidence.low,
      ),
    );
  }
}

enum BiasBand {
  neutral, // 0-25
  mild, // 26-50
  notable, // 51-75
  heavy, // 76-100
}

extension BiasBandLabel on BiasBand {
  String get label => switch (this) {
        BiasBand.neutral => 'Nötr',
        BiasBand.mild => 'Hafif yönlü',
        BiasBand.notable => 'Belirgin yönlü',
        BiasBand.heavy => 'Yüksek yönlü',
      };
}

enum BiasConfidence { low, medium, high }

extension BiasConfidenceLabel on BiasConfidence {
  String get label => switch (this) {
        BiasConfidence.low => 'Düşük güven',
        BiasConfidence.medium => 'Orta güven',
        BiasConfidence.high => 'Yüksek güven',
      };
}
