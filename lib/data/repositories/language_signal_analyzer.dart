import '../../core/utils/turkish_text.dart';

/// Metinde bulunan tek bir dil sinyali.
class LanguageCue {
  const LanguageCue(this.kind, this.text, this.weight);

  final LanguageCueKind kind;

  /// Metinde geçen ifade (ör. "skandal", "!!", "ŞOK").
  final String text;
  final int weight;
}

enum LanguageCueKind {
  /// Duygu yüklü / abartılı kelime.
  loaded,

  /// Tıklama tuzağı kalıbı ("işte", "bakın", "herkes bunu konuşuyor").
  clickbait,

  /// Karşı tarafı küçümseyen niteleyici ("sözde", "güya").
  delegitimizing,

  /// Ünlem, büyük harf, retorik soru gibi biçim sinyalleri.
  typographic,
}

/// Dil sinyali analizinin sonucu. [score] 0-100.
class LanguageSignals {
  const LanguageSignals(this.score, this.cues);

  final int score;
  final List<LanguageCue> cues;
}

/// Haber manşeti ve metnindeki yönlendirici dil sinyallerini **sözlük ve
/// kural tabanlı**, deterministik biçimde ölçer. Cihazda çalışır, AI
/// gerektirmez; aynı metin her zaman aynı sonucu verir.
///
/// LLM'in yönlülük skoru tekrar üretilebilir ve kalibre değildir; bu
/// analizör onun yanında bağımsız ve açıklanabilir bir ikinci ölçüm sağlar.
/// İkisi uyuşmazsa sonuç "düşük güven" olarak gösterilir.
///
/// Manşetteki sinyaller metindekilerin iki katı ağırlık alır (okurun çoğu
/// yalnızca manşeti görür).
class LanguageSignalAnalyzer {
  const LanguageSignalAnalyzer();

  /// Kök → ağırlık. Kökler [trLower] biçiminde; ekli hâlleri de eşleşir.
  /// Haber dilinde düz anlamıyla da sık geçen kelimeler ("bomba yüklü
  /// araç", "deprem felaketi", "binanın çöküşü") bilinçli olarak yok.
  static const Map<String, int> _loaded = {
    'skandal': 12, 'rezalet': 12, 'utanç': 10, 'şok': 10,
    'dehşet': 10, 'vahşet': 8, 'kahreden': 8, 'korkunç': 8,
    'çılgın': 8, 'inanılmaz': 8, 'akılalmaz': 8, 'muhteşem': 6,
    'efsane': 6, 'hezimet': 10, 'fiyasko': 10, 'tokat': 8,
    'şamar': 10, 'hain': 12, 'alçak': 12, 'kirli': 6, 'kara propaganda': 10,
    'yürek burkan': 8, 'kan dondurdu': 10, 'ortalık karıştı': 8,
    'sosyal medya yıkıldı': 10, 'olay sözler': 8, 'olay yaratan': 6,
  };

  static const Map<String, int> _clickbait = {
    'işte': 6, 'bakın': 8, 'herkes bunu': 10, 'ağızları açık': 10,
    'görenler şaşkın': 10, 'kimse beklemiyordu': 8, 'flaş': 4,
  };

  /// Büyük harfle yazılan ama vurgu olmayan yaygın kurum adları.
  static const Set<String> _acronyms = {
    'aselsan', 'tübitak', 'teknofest', 'unesco', 'unicef', 'roketsan',
    'havelsan', 'nasdaq', 'opec',
  };

  static const Map<String, int> _delegitimizing = {
    'sözde': 10, 'güya': 10, 'sözümona': 12, 'sözüm ona': 12,
    'kendini bilmez': 12,
  };

  LanguageSignals analyze({required String title, String body = ''}) {
    final cues = <LanguageCue>[];
    var raw = 0;

    void scan(String text, int multiplier) {
      final tokens = trTokens(text);
      void lexicon(Map<String, int> map, LanguageCueKind kind) {
        map.forEach((kw, w) {
          if (_containsPhrase(tokens, kw)) {
            cues.add(LanguageCue(kind, kw, w * multiplier));
            raw += w * multiplier;
          }
        });
      }

      lexicon(_loaded, LanguageCueKind.loaded);
      lexicon(_clickbait, LanguageCueKind.clickbait);
      lexicon(_delegitimizing, LanguageCueKind.delegitimizing);
    }

    scan(title, 2);
    if (body.isNotEmpty) scan(body, 1);

    // Biçim sinyalleri yalnızca manşette anlamlı.
    final exclamations = '!'.allMatches(title).length;
    if (exclamations > 0) {
      final w = exclamations > 1 ? 12 : 6;
      cues.add(LanguageCue(LanguageCueKind.typographic, '!', w));
      raw += w;
    }
    if (title.trim().endsWith('?')) {
      cues.add(const LanguageCue(LanguageCueKind.typographic, '?', 6));
      raw += 6;
    }
    final words = title
        .split(RegExp(r'\s+'))
        .where((w) => RegExp(r'\p{L}{3,}', unicode: true).hasMatch(w))
        .toList();
    // 5 harften kısa büyük harfli kelimeler genelde kısaltmadır
    // (AFAD, TBMM, NATO, ABD) — vurgu sayılmaz.
    final caps = words.where((w) {
      final letters =
          w.split(RegExp("['’]")).first.replaceAll(
              RegExp(r'[^\p{L}]', unicode: true), '');
      return letters.length >= 5 &&
          letters == letters.toUpperCase() &&
          letters != letters.toLowerCase() &&
          !_acronyms.contains(trLower(letters));
    }).toList();
    // Tamamı büyük harf manşetler (bazı kaynakların stili) değil, içinde
    // tek tük vurgulu BÜYÜK kelime olanlar sinyaldir.
    if (caps.isNotEmpty && caps.length < words.length) {
      cues.add(LanguageCue(
          LanguageCueKind.typographic, caps.take(2).join(' '), 8));
      raw += 8;
    }

    if (title.contains('...') || title.contains('…')) {
      cues.add(const LanguageCue(LanguageCueKind.typographic, '…', 4));
      raw += 4;
    }

    return LanguageSignals(raw.clamp(0, 100), cues);
  }

  static bool _containsPhrase(List<String> tokens, String phrase) {
    final parts = phrase.split(' ');
    for (var i = 0; i + parts.length <= tokens.length; i++) {
      var ok = true;
      for (var j = 0; j < parts.length; j++) {
        if (!stemMatches(tokens[i + j], parts[j])) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }
}
