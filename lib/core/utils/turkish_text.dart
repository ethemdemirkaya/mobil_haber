/// Türkçe metin işleme yardımcıları.
///
/// Dart'ın `toLowerCase()`'i locale bilmez: `"ALTIN".toLowerCase()` →
/// `"altin"` (doğrusu `"altın"`). Büyük harf manşetlerde (ör. "SON DAKİKA",
/// "SAĞLIK") kelime eşleşmeleri bu yüzden kaçıyordu.
library;

/// Türkçe kurallarıyla küçük harfe çevirir (I → ı, İ → i). Şapkalı harfler
/// (â, î, û) sadeleştirilir — "zekâ" ile "zeka" aynı kabul edilir.
String trLower(String s) => s
    .replaceAll('I', 'ı')
    .replaceAll('İ', 'i')
    .toLowerCase()
    .replaceAll('̇', '') // olası birleşik nokta (i̇) artığı
    .replaceAll('â', 'a')
    .replaceAll('î', 'i')
    .replaceAll('û', 'u');

/// [trLower] + Türkçe karakterleri ASCII'ye katlar (ı→i, ş→s, …).
/// Klavyesinde Türkçe karakter olmayan kullanıcının "saglik" araması
/// "Sağlık" ile eşleşsin diye arama ve filtrelerde kullanılır.
String foldTr(String s) => trLower(s)
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ç', 'c')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ğ', 'g');

final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Metni [trLower] edilmiş kelimelere böler. Kesme işareti de ayırıcıdır:
/// "Erdoğan'ın" → ["erdoğan", "ın"].
List<String> trTokens(String s) => trLower(s)
    .split(_nonWord)
    .where((t) => t.isNotEmpty)
    .toList(growable: false);

/// Kök + çekim eki eşleşmesi için kullanılan yaygın Türkçe ek biçimleri.
/// Bilinçli olarak tek harfli "n", "k" gibi ekler yok — "uzay" → "uzayan",
/// "aşı" → "aşık" gibi yanlış eşleşmeleri önler.
const Set<String> _suffixes = {
  // çoğul
  'lar', 'ler',
  // iyelik / belirtme / yönelme
  'ı', 'i', 'u', 'ü', 'sı', 'si', 'su', 'sü', 'yı', 'yi', 'yu', 'yü',
  'a', 'e', 'ya', 'ye', 'na', 'ne', 'nı', 'ni', 'nu', 'nü',
  'ım', 'im', 'um', 'üm', 'ın', 'in', 'un', 'ün',
  // tamlayan
  'nın', 'nin', 'nun', 'nün',
  // bulunma / ayrılma
  'da', 'de', 'ta', 'te', 'dan', 'den', 'tan', 'ten',
  'nda', 'nde', 'ndan', 'nden',
  // -ki, ek fiil, vasıta
  'ki', 'daki', 'deki', 'taki', 'teki', 'ndaki', 'ndeki',
  'dır', 'dir', 'dur', 'dür', 'tır', 'tir', 'tur', 'tür',
  'la', 'le', 'yla', 'yle',
  // yapım ekleri (anlamı koruyanlar)
  'lı', 'li', 'lu', 'lü', 'cı', 'ci', 'cu', 'cü', 'çı', 'çi', 'çu', 'çü',
  'sal', 'sel', 'lık', 'lik', 'luk', 'lük',
};

/// [token], [stem] kökünden ve ardından gelen geçerli ek dizisinden mi
/// oluşuyor? `stemMatches('maçta', 'maç')` → true,
/// `stemMatches('operasyon', 'opera')` → false.
bool stemMatches(String token, String stem) {
  if (token == stem) return true;
  if (!token.startsWith(stem)) return false;
  return _isSuffixChain(token.substring(stem.length), 0);
}

bool _isSuffixChain(String rest, int depth) {
  if (rest.isEmpty) return true;
  if (depth >= 4) return false;
  for (var len = rest.length < 5 ? rest.length : 5; len >= 1; len--) {
    if (_suffixes.contains(rest.substring(0, len)) &&
        _isSuffixChain(rest.substring(len), depth + 1)) {
      return true;
    }
  }
  return false;
}

/// Sözlüksüz Türkçe "kök" çıkarımı: kelimenin ilk [prefix] harfi (F5).
///
/// Türkçe bilgi erişimi çalışmalarında (Can vd., 2008, JASIST) sabit önek
/// kırpmanın sözlük tabanlı kök bulucularla yarışır sonuç verdiği
/// raporlanmıştır. Ek atma kurallarındaki belirsizliklere ("bakanı" →
/// "bakan+ı" mı "baka+nı" mı?) takılmaz; aynı kelimenin ekli hâllerini
/// tutarlı biçimde aynı anahtara indirir:
/// "seçim", "seçimlerde", "seçimin" → "seçim"; "bakan", "bakanı" → "bakan".
String stemTr(String token, {int prefix = 5}) =>
    token.length <= prefix ? token : token.substring(0, prefix);
