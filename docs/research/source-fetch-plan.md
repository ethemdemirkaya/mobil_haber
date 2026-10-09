# Kaynak başına çekim planı

Tarih: 10 Ekim 2026. Uygulamadaki karşılığı: `lib/data/sources/news_aggregator.dart`.
Codex'in yayıncı API araştırmasının (`publisher-api-review.md`) devamıdır; bu çalışma
56 kaynağın tamamını aynı yöntemle yokladı.

## Yöntem

Yalnızca herkese açık GET istekleri; giriş, trafik çözümleme ya da erişim engelini aşma yok.
Her kaynak için:

1. RSS feed'i (durum ve öğe sayısı).
2. `/wp-json/wp/v2/posts` (WordPress REST) — JSON liste dönüyor mu.
3. Ana sayfada API izleri: WordPress keşif bağlantısı, Next.js/Angular sunucu verisi,
   `api` içeren alan adları; bulunan adaylara GET ve JSON kontrolü.
4. 20 büyük sitenin kendi JavaScript dosyalarında `fetch`/`/api/` çağrıları; adaylara GET.
5. Bir haber sayfasında gömülü veri: JSON-LD `articleBody`, `__NEXT_DATA__`, `ng-state`,
   Euronews sunucu verisi.

## Sonuç

Doğrudan kullanılabilen herkese açık haber **API'si** yalnızca 4 kaynakta bulundu.
Diğerlerinde RSS en zengin liste kaynağı; tam metin (AI özeti/sesli okuma için) haber
sayfasındaki gömülü veriden okunuyor. Her plan RSS ile biter: API kapanır ya da şeması
değişirse kaynak kaybolmaz.

| Kaynak | Liste planı | RSS | Tam metin |
|---|---|---|---|
| Anadolu Ajansı | RSS | çalışıyor | paragraf taraması |
| TRT Haber | RSS | çalışıyor | paragraf taraması |
| Sabah | RSS | çalışıyor | JSON-LD `articleBody`² |
| Sözcü | RSS | çalışıyor | paragraf taraması |
| Hürriyet | RSS | çalışıyor | paragraf taraması |
| Milliyet | RSS | çalışıyor | paragraf taraması |
| Cumhuriyet | RSS | çalışıyor¹ | paragraf taraması |
| Habertürk | Habertürk API (gündem, dünya) → RSS | çalışıyor | paragraf taraması |
| CNN Türk | RSS | çalışıyor | paragraf taraması |
| NTV | RSS | çalışıyor | JSON-LD `articleBody` |
| Yeni Şafak | RSS | çalışıyor | paragraf taraması |
| Diken | WordPress API → RSS | çalışıyor | API gövdesi |
| BBC Türkçe | RSS | çalışıyor | BBC `__NEXT_DATA__` |
| DW Türkçe | RSS | çalışıyor | paragraf taraması |
| Euronews Türkçe | RSS | çalışıyor | Euronews sunucu verisi |
| Independent Türkçe | RSS | çalışıyor | paragraf taraması |
| Gazete Duvar | RSS | çalışıyor | paragraf taraması |
| Artı Gerçek | RSS | çalışıyor | paragraf taraması |
| Karar | RSS | çalışıyor | paragraf taraması |
| Halk TV | RSS | çalışıyor | paragraf taraması |
| TELE1 | RSS | çalışıyor | JSON-LD `articleBody` |
| OdaTV | RSS | çalışıyor | paragraf taraması |
| Aydınlık | RSS | çalışıyor | paragraf taraması |
| Yeniçağ | RSS | çalışıyor | paragraf taraması |
| Veryansın TV | RSS | çalışıyor | paragraf taraması |
| Medyascope | WordPress API → RSS | çalışıyor | API gövdesi |
| Gerçek Gündem | RSS | çalışıyor | paragraf taraması |
| Vatan | RSS | çalışıyor | paragraf taraması |
| Türkiye Gazetesi | RSS | çalışıyor | paragraf taraması |
| İnternethaber | RSS | çalışıyor | paragraf taraması |
| Nethaber | RSS | çalışıyor | paragraf taraması |
| Investing.com Türkçe | RSS | çalışıyor | erişim yok (403) |
| Bloomberg HT | RSS | çalışıyor | paragraf taraması |
| Dünya Gazetesi | RSS | çalışıyor | paragraf taraması |
| Bigpara | RSS | HTTP 403 | paragraf taraması |
| Ekonomim | RSS | çalışıyor | paragraf taraması |
| Webrazzi | RSS | çalışıyor | JSON-LD `articleBody` |
| ShiftDelete.Net | WordPress API → RSS | çalışıyor | API gövdesi |
| Donanım Haber | RSS | çalışıyor | JSON-LD `articleBody` |
| Webtekno | RSS | çalışıyor | paragraf taraması |
| CHIP Online | RSS | çalışıyor | paragraf taraması |
| Tamindir | RSS | çalışıyor | JSON-LD `articleBody` |
| Fotomaç | RSS | çalışıyor | paragraf taraması |
| A Spor | RSS | çalışıyor | paragraf taraması |
| Posta | RSS | çalışıyor | paragraf taraması |
| Akşam | RSS | çalışıyor | paragraf taraması |
| Takvim | RSS | çalışıyor | paragraf taraması |
| A Haber | RSS | çalışıyor | paragraf taraması |
| Star | RSS | çalışıyor | paragraf taraması |
| Bianet | RSS | çalışıyor | paragraf taraması |
| Mynet | RSS | çalışıyor | paragraf taraması |
| Haber Global | RSS | çalışıyor | paragraf taraması |
| Habertürk Genç | RSS | boş | paragraf taraması |
| Daily Sabah | RSS | çalışıyor | JSON-LD `articleBody` |
| Hürriyet Daily News | RSS | boş | paragraf taraması |
| AA English | RSS | çalışıyor | paragraf taraması |

¹ Python yoklamasında bağlantı kurulamadı; curl ile 100 öğe döndüğü ayrıca doğrulandı.
² Yoklamanın seçtiği haber sayfasında yoktu; başka bir Sabah haberinde `articleBody` doğrulandı
(sayfa türüne göre değişiyor, olmadığında paragraf taramasına düşülür).

## İncelenip kullanılmayanlar

- **Bianet** `/api/Category/CategoryLatestContentGetList`: JSON zarfı içinde hazır **HTML
  parçası** döndürüyor (başlık, görsel, gün). Yapılandırılmış veri değil; RSS daha zengin.
- **Sözcü** `apiv2.sozcu.com.tr`: dokümantasyon bağlantıları 404; haber uç noktası yok.
- **Turkuvaz grubu** `webapi.tmgrup.com.tr` (Sabah, A Haber, Takvim, Fotomaç, A Spor,
  Daily Sabah): bulunan yol 404.
- **Hürriyet/Milliyet** `/api/*`: döviz, coğrafi konum, uygulama yönlendirme — haber değil.
- **Mynet** `/spor/json-api/live-match-widget`: canlı skor — haber değil.
- **BBC** `.json` veri uç noktası: 404. Metin sayfaya gömülü `__NEXT_DATA__`'dan okunuyor.
- **Veryansın TV** WordPress API'si 403, **Investing** makale sayfaları 403, **Bigpara**
  RSS 403: erişim reddediliyor; aşılmaya çalışılmadı.
- Diğer `api` adayları analitik, reklam, push bildirimi, IP konumu ve yorum servisleri.

## Sınırlar

- Ölçümler tek anlık durumdur; yayıncılar şemayı değiştirebilir. Tanılama ekranı
  (Ayarlar › Tanılama) her kaynağın o anki yöntemini ve sonucunu gösterir.
- Habertürk API'sinde `spot` haberin özetidir, tam metni değil.
- Bir API'nin erişilebilir olması yeniden yayımlama izni anlamına gelmez; uygulama
  haberin tamamını kendi arşivinde saklamaz, kaynağa bağlantı verir.
