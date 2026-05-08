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
class BiasReport {
  const BiasReport({
    required this.score,
    required this.label,
    required this.cues,
    required this.summary,
  });

  /// 0-100 arası bias skoru.
  final int score;

  /// İnsan-okuyabilir kategori: "Nötr", "Hafif yönlü", "Belirgin yönlü",
  /// "Yüksek yönlü".
  final String label;

  /// Modelin tespit ettiği "ipucu" kelime/ifade örnekleri (max 5 kısa
  /// öğe). UI rozet listesi olarak gösterir.
  final List<String> cues;

  /// 1-2 cümlelik açıklama: "Manşet 'çıkmaza saplandı' gibi yorum
  /// içeren kelimeler kullanmış" gibi.
  final String summary;

  /// Skoru renk için 4 banta indirger (UI tarafında renge map'lenir).
  BiasBand get band {
    if (score <= 25) return BiasBand.neutral;
    if (score <= 50) return BiasBand.mild;
    if (score <= 75) return BiasBand.notable;
    return BiasBand.heavy;
  }

  Map<String, Object?> toJson() => {
        'score': score,
        'label': label,
        'cues': cues,
        'summary': summary,
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
    return BiasReport(
      score: score.clamp(0, 100),
      label: label,
      cues: cues.take(5).toList(growable: false),
      summary: summary,
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
