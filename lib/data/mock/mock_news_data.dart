import '../models/article.dart';

class MockNewsData {
  MockNewsData._();

  static String _img(String seed) =>
      'https://picsum.photos/seed/$seed/1200/800';

  static const String _loremShort =
      'Bu haber içeriği, mobil_haber demo uygulamasında okuma deneyimini '
      'göstermek için hazırlanmıştır. Gerçek bir haber kaynağına bağlı '
      'değildir.';

  static String _body(String topic) {
    return '''
$topic konusu son günlerde gündemin üst sıralarında yer alıyor. Uzmanlar, gelişmelerin önümüzdeki haftalarda hız kesmeden süreceğini belirtirken, kamuoyunun konuya gösterdiği ilgi de dikkat çekiyor.

Konunun arka planında bir dizi yapısal etken bulunuyor. Akademisyenler ve sektör temsilcileri, alınacak kararların uzun vadeli sonuçları olabileceğine dikkat çekti. Yapılan açıklamalarda, sürecin şeffaf bir biçimde yürütülmesinin önemi vurgulandı.

Vatandaşlar ise sosyal medyada konuya ilişkin görüşlerini paylaşıyor. Yorumların büyük bölümünde, somut adımların hızla atılmasının beklendiği ifade ediliyor. Yetkililer, gelecek günlerde detaylı bir yol haritası açıklayacaklarını duyurdu.

mobil_haber, gelişmeleri yakından takip etmeye devam edecek. Konuyla ilgili yeni bilgiler ulaştıkça okurlarımızla paylaşılacak.

(Bu içerik demonstrasyon amaçlıdır.)
''';
  }

  static final List<Article> articles = [
    Article(
      id: 'a1',
      title: 'Merkez Bankası faiz kararını açıkladı, piyasalar tepki verdi',
      summary:
          'Para Politikası Kurulu, beklentilerin aksine politika faizini sabit '
          'tuttu; borsada hareketlilik gözlendi.',
      content: _body('Merkez Bankası faiz kararı'),
      categoryId: 'ekonomi',
      imageUrl: _img('finance1'),
      author: 'Ayşe Yıldız',
      publishedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      readMinutes: 4,
      isFeatured: true,
    ),
    Article(
      id: 'a2',
      title: 'Süper Lig\'de derbi heyecanı: Galibiyet son dakikada geldi',
      summary:
          'Nefes kesen mücadele, uzatma dakikalarındaki golle sonuçlandı. '
          'Taraftarlar maç sonunda meydanları doldurdu.',
      content: _body('Süper Lig derbisi'),
      categoryId: 'spor',
      imageUrl: _img('soccer1'),
      author: 'Mehmet Kaya',
      publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
      readMinutes: 3,
      isFeatured: true,
    ),
    Article(
      id: 'a3',
      title: 'Yapay zekâ destekli yeni nesil işlemci tanıtıldı',
      summary:
          'Çip üreticisi, mobil cihazlarda yapay zekâ performansını ikiye '
          'katlayan modeli duyurdu. Lansman sonbaharda.',
      content: _body('Yeni nesil yapay zekâ işlemcisi'),
      categoryId: 'teknoloji',
      imageUrl: _img('chip1'),
      author: 'Eren Demir',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      readMinutes: 5,
      isFeatured: true,
    ),
    Article(
      id: 'a4',
      title: 'Mars\'tan dönen örneklerde organik bileşikler tespit edildi',
      summary:
          'Bilim insanları, Kızıl Gezegen\'den getirilen örneklerde yaşamın '
          'temel taşı sayılan moleküllere ulaştı.',
      content: _body('Mars örneklerinde organik bileşikler'),
      categoryId: 'bilim',
      imageUrl: _img('mars1'),
      author: 'Dr. Selin Aydın',
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
      readMinutes: 6,
      isFeatured: true,
    ),
    Article(
      id: 'a5',
      title: 'İstanbul\'da yeni metro hattı hizmete açılıyor',
      summary:
          'Şehrin doğu-batı aksını birbirine bağlayacak yeni hat, günlük 800 '
          'bin yolcuya hizmet vermeyi hedefliyor.',
      content: _body('İstanbul yeni metro hattı'),
      categoryId: 'gundem',
      imageUrl: _img('metro1'),
      author: 'Burak Şahin',
      publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
      readMinutes: 4,
      isFeatured: true,
    ),
    Article(
      id: 'a6',
      title: 'Avrupa Birliği yeni dijital pazar düzenlemesini kabul etti',
      summary: _loremShort,
      content: _body('AB dijital pazar düzenlemesi'),
      categoryId: 'dunya',
      imageUrl: _img('eu1'),
      author: 'Cem Aksoy',
      publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
      readMinutes: 5,
    ),
    Article(
      id: 'a7',
      title: 'Yaz tatili rotaları: Bu yıl ön plana çıkan 5 sakin koy',
      summary: _loremShort,
      content: _body('Sakin koy rotaları'),
      categoryId: 'seyahat',
      imageUrl: _img('beach1'),
      author: 'Defne Aslan',
      publishedAt: DateTime.now().subtract(const Duration(hours: 7)),
      readMinutes: 4,
    ),
    Article(
      id: 'a8',
      title: 'Kalp sağlığı için günde 30 dakika yürüyüşün etkisi',
      summary: _loremShort,
      content: _body('Yürüyüşün kalp sağlığına etkisi'),
      categoryId: 'saglik',
      imageUrl: _img('walk1'),
      author: 'Dr. Hakan Öz',
      publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      readMinutes: 3,
    ),
    Article(
      id: 'a9',
      title: 'Üniversite tercih süreci başladı: Adaylar için kritik 7 ipucu',
      summary: _loremShort,
      content: _body('Üniversite tercih süreci ipuçları'),
      categoryId: 'egitim',
      imageUrl: _img('uni1'),
      author: 'Zeynep Korkmaz',
      publishedAt: DateTime.now().subtract(const Duration(hours: 10)),
      readMinutes: 6,
    ),
    Article(
      id: 'a10',
      title: 'Yerli oyun stüdyosu Steam\'de zirveye yerleşti',
      summary: _loremShort,
      content: _body('Yerli oyun stüdyosu başarısı'),
      categoryId: 'teknoloji',
      imageUrl: _img('game1'),
      author: 'Eren Demir',
      publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
      readMinutes: 4,
    ),
    Article(
      id: 'a11',
      title: 'Şampiyonlar Ligi: Türk takımı çeyrek final hesabı yapıyor',
      summary: _loremShort,
      content: _body('Şampiyonlar Ligi çeyrek final'),
      categoryId: 'spor',
      imageUrl: _img('soccer2'),
      author: 'Mehmet Kaya',
      publishedAt: DateTime.now().subtract(const Duration(hours: 14)),
      readMinutes: 3,
    ),
    Article(
      id: 'a12',
      title: 'Dolar/TL kuru ve altın fiyatları: Günün son rakamları',
      summary: _loremShort,
      content: _body('Döviz ve altın fiyatları'),
      categoryId: 'ekonomi',
      imageUrl: _img('finance2'),
      author: 'Ayşe Yıldız',
      publishedAt: DateTime.now().subtract(const Duration(hours: 16)),
      readMinutes: 2,
    ),
    Article(
      id: 'a13',
      title: 'Modern sanat sergisi İstanbul Modern\'de kapılarını açtı',
      summary: _loremShort,
      content: _body('Modern sanat sergisi'),
      categoryId: 'sanat',
      imageUrl: _img('art1'),
      author: 'Lale Ergin',
      publishedAt: DateTime.now().subtract(const Duration(hours: 18)),
      readMinutes: 5,
    ),
    Article(
      id: 'a14',
      title: 'Yeni nesil elektrikli otomobiller menzil rekoru kırıyor',
      summary: _loremShort,
      content: _body('Elektrikli otomobil menzil rekoru'),
      categoryId: 'teknoloji',
      imageUrl: _img('ev1'),
      author: 'Eren Demir',
      publishedAt: DateTime.now().subtract(const Duration(hours: 20)),
      readMinutes: 4,
    ),
    Article(
      id: 'a15',
      title: 'Kahve kültürü: Üçüncü dalga kafelerin yükselişi',
      summary: _loremShort,
      content: _body('Üçüncü dalga kahve kültürü'),
      categoryId: 'yasam',
      imageUrl: _img('coffee1'),
      author: 'Defne Aslan',
      publishedAt: DateTime.now().subtract(const Duration(hours: 22)),
      readMinutes: 4,
    ),
    Article(
      id: 'a16',
      title: 'Kuantum bilgisayarda yeni rekor: 1000 kübitlik sistem',
      summary: _loremShort,
      content: _body('Kuantum bilgisayar yeni rekor'),
      categoryId: 'bilim',
      imageUrl: _img('quantum1'),
      author: 'Dr. Selin Aydın',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      readMinutes: 7,
    ),
    Article(
      id: 'a17',
      title: 'Edebiyat ödülü bu yıl genç bir kadın yazara gitti',
      summary: _loremShort,
      content: _body('Edebiyat ödülü töreni'),
      categoryId: 'kultur',
      imageUrl: _img('books1'),
      author: 'Lale Ergin',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 1, hours: 2)),
      readMinutes: 5,
    ),
    Article(
      id: 'a18',
      title: 'Asya pazarlarında karışık seyir: Yatırımcı temkinli',
      summary: _loremShort,
      content: _body('Asya pazarları karışık seyir'),
      categoryId: 'ekonomi',
      imageUrl: _img('market1'),
      author: 'Ayşe Yıldız',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 1, hours: 4)),
      readMinutes: 3,
    ),
    Article(
      id: 'a19',
      title: 'Japonya\'da ileri teknoloji robotlar yaşlı bakımına giriyor',
      summary: _loremShort,
      content: _body('Robotik yaşlı bakımı'),
      categoryId: 'dunya',
      imageUrl: _img('robot1'),
      author: 'Cem Aksoy',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 1, hours: 6)),
      readMinutes: 6,
    ),
    Article(
      id: 'a20',
      title: 'Gece koşusu trendi: Şehirlerde yeni bir spor kültürü',
      summary: _loremShort,
      content: _body('Gece koşusu trendi'),
      categoryId: 'spor',
      imageUrl: _img('run1'),
      author: 'Mehmet Kaya',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 1, hours: 8)),
      readMinutes: 4,
    ),
    Article(
      id: 'a21',
      title: 'Sağlıklı uyku için akşam rutini: 6 küçük değişiklik',
      summary: _loremShort,
      content: _body('Sağlıklı uyku rutini'),
      categoryId: 'saglik',
      imageUrl: _img('sleep1'),
      author: 'Dr. Hakan Öz',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 1, hours: 12)),
      readMinutes: 5,
    ),
    Article(
      id: 'a22',
      title: 'Kapadokya\'da balon sezonu rekor sayıyla başladı',
      summary: _loremShort,
      content: _body('Kapadokya balon sezonu'),
      categoryId: 'seyahat',
      imageUrl: _img('balloon1'),
      author: 'Defne Aslan',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 1, hours: 18)),
      readMinutes: 3,
    ),
    Article(
      id: 'a23',
      title: 'STEM eğitimi: Ortaokulda kodlama dersleri yaygınlaşıyor',
      summary: _loremShort,
      content: _body('STEM eğitimi yaygınlaşması'),
      categoryId: 'egitim',
      imageUrl: _img('code1'),
      author: 'Zeynep Korkmaz',
      publishedAt:
          DateTime.now().subtract(const Duration(days: 2)),
      readMinutes: 5,
    ),
    Article(
      id: 'a24',
      title: 'Tiyatro festivali bu yıl 28 ülkeden topluluğu ağırlıyor',
      summary: _loremShort,
      content: _body('Uluslararası tiyatro festivali'),
      categoryId: 'kultur',
      imageUrl: _img('theatre1'),
      author: 'Lale Ergin',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 2, hours: 4)),
      readMinutes: 4,
    ),
    Article(
      id: 'a25',
      title: 'Genç ressamların ortak sergisi: 12 farklı bakış',
      summary: _loremShort,
      content: _body('Genç ressamlar ortak sergisi'),
      categoryId: 'sanat',
      imageUrl: _img('paint1'),
      author: 'Lale Ergin',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 2, hours: 8)),
      readMinutes: 4,
    ),
    Article(
      id: 'a26',
      title: 'Uzaktan çalışma kalıcı: Şirketlerin yeni iş modelleri',
      summary: _loremShort,
      content: _body('Uzaktan çalışma yeni modeller'),
      categoryId: 'yasam',
      imageUrl: _img('remote1'),
      author: 'Burak Şahin',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 2, hours: 12)),
      readMinutes: 5,
    ),
    Article(
      id: 'a27',
      title: 'Bulut bilişim pazarında yerli oyuncuların payı artıyor',
      summary: _loremShort,
      content: _body('Yerli bulut bilişim'),
      categoryId: 'teknoloji',
      imageUrl: _img('cloud1'),
      author: 'Eren Demir',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 3)),
      readMinutes: 4,
    ),
    Article(
      id: 'a28',
      title: 'Akdeniz\'de yeni arkeolojik buluntular gün yüzüne çıktı',
      summary: _loremShort,
      content: _body('Akdeniz arkeolojik buluntular'),
      categoryId: 'kultur',
      imageUrl: _img('arch1'),
      author: 'Lale Ergin',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 3, hours: 6)),
      readMinutes: 6,
    ),
    Article(
      id: 'a29',
      title: 'Türkiye\'nin uydu programı: Yeni nesil görüntüleme uydusu yolda',
      summary: _loremShort,
      content: _body('Yeni nesil uydu'),
      categoryId: 'bilim',
      imageUrl: _img('satellite1'),
      author: 'Dr. Selin Aydın',
      publishedAt: DateTime.now()
          .subtract(const Duration(days: 3, hours: 12)),
      readMinutes: 5,
    ),
    Article(
      id: 'a30',
      title: 'Şehir bisikleti ağı genişliyor: Yeni 200 istasyon',
      summary: _loremShort,
      content: _body('Şehir bisikleti ağı'),
      categoryId: 'gundem',
      imageUrl: _img('bike1'),
      author: 'Burak Şahin',
      publishedAt:
          DateTime.now().subtract(const Duration(days: 4)),
      readMinutes: 3,
    ),
  ];

  static List<Article> featured() =>
      articles.where((a) => a.isFeatured).toList();

  static List<Article> byCategory(String categoryId) {
    if (categoryId == 'all') return List.of(articles);
    return articles.where((a) => a.categoryId == categoryId).toList();
  }
}
