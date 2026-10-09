/// Haber asistanı cevabının neye dayandığı.
enum QaGrounding {
  /// Yalnızca haber metnindeki bilgi.
  article,

  /// Modelin genel bilgisi — haberde geçmiyor, doğrulanmalı.
  background,

  /// Soru haberle ilgili değil.
  offTopic,
}

class QaAnswer {
  const QaAnswer(this.text, this.grounding);

  final String text;
  final QaGrounding grounding;

  static final RegExp _tag = RegExp(
    r'^\s*\[(HABERDE|GENEL BİLGİ|GENEL BILGI|ALAKASIZ)\]\s*',
    caseSensitive: false,
  );

  /// Modelin `[HABERDE]` / `[GENEL BİLGİ]` / `[ALAKASIZ]` önekli çıktısını
  /// ayrıştırır. Önek yoksa temkinli davranıp genel bilgi kabul edilir.
  factory QaAnswer.parse(String raw) {
    final m = _tag.firstMatch(raw);
    if (m == null) return QaAnswer(raw.trim(), QaGrounding.background);
    final tag = m.group(1)!.toUpperCase();
    final grounding = tag == 'HABERDE'
        ? QaGrounding.article
        : tag == 'ALAKASIZ'
            ? QaGrounding.offTopic
            : QaGrounding.background;
    return QaAnswer(raw.substring(m.end).trim(), grounding);
  }
}
