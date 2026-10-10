# Yayıncıların kendi API'lerinden haber alma araştırması

Tarih: 10 Ekim 2026. Önceki [kaynak incelemesinin](news-ingestion-review.md) devamıdır.
Ölçümler: [publisher-api-audit.json](publisher-api-audit.json).

## Sonuç

RSS dışında yayıncının kendi JSON uç noktalarını kullanmak bazı kaynaklarda mümkün.
Üç WordPress yayınının listeleme, sayfalama ve haber detayı canlı olarak doğrulandı.
Habertürk'ün kendi kategori API'si de çalışıyor; burada tam haber detayı henüz doğrulanmadı.
DonanımHaber, BBC Türkçe ve Euronews'te ise sayfanın içine gömülmüş yapılandırılmış haber verisi bulundu.
Bu üç bulgu, ayrı bir API adresine doğrudan istek atmanın doğrulandığı anlamına gelmiyor.

Dolayısıyla bütün kaynakları tek bir gizli API üzerinden çekmek mümkünmüş gibi bir varsayım yapmamalıyız.
Doğrulanmış API + kaynağa özel gömülü veri okuyucusu + HTML/RSS yedeği öneriyorum.
Bir API adresinin erişilebilir olması, yeniden yayımlama/kalıcı arşivleme izni veya süreklilik garantisi değildir.

## Araştırmanın kapsamı

- Önceki 56 kaynak araştırmasından kalan, erişilebilir **52 kaynağın ilk haber HTML'i** üzerinde JSON alternate bağlantıları, WordPress keşif bağlantıları ve bilinen gömülü veri blokları tarandı. Bu sayı 52 sitede API çalıştığı anlamına gelmez.
- Habertürk, Sözcü ve Halk TV'nin ilgili herkese açık JavaScript dosyalarındaki çağrılar da incelendi.
- Üç WordPress yayını için ikişer kayıt içeren iki liste sayfası ve ilk kaydın detay adresi yeniden istendi.
- Habertürk'te yanıtın kendi `next` bağlantısı takip edilerek iki kategori sayfası istendi.
- DonanımHaber, BBC Türkçe ve Euronews'te birer haber sayfası yeniden indirildi ve yapılandırılmış alanlar ölçüldü.
- Sözcü API ana sayfasının verdiği üç dokümantasyon bağlantısı denendi.
- Yöntem HTTP GET ve HTML/JS incelemesidir; tarayıcı Network kaydı, mobil uygulama trafik çözümleme veya kimlik doğrulamalı bir oturum kullanılmadı. Erişim engeli aşılmadı.
- Bunlar sınırlı örneklerdir. Haberlerin tamamının, arşivin veya tüm içerik türlerinin alınabileceği doğrulanmadı. Karakter sayısı tek başına eksiksizlik ölçütü değildir.

## Doğrulanan API'ler

| Kaynak | Liste/sayfalama | Haber detayı | Örnek ölçüm |
|---|---|---|---|
| Diken | İki sayfa HTTP 200, dört ayrı haber | ID ile HTTP 200 | İlk detay gövdesi 1.679 karakter |
| Medyascope | İki sayfa HTTP 200, dört ayrı haber | ID ile HTTP 200 | İlk detay gövdesi 7.780 karakter |
| ShiftDelete | İki sayfa HTTP 200, dört ayrı haber | ID ile HTTP 200 | İlk detay gövdesi 3.187 karakter |
| Habertürk | İki sayfa HTTP 200; ilkinde 73, ikincide 36 ayrı `newsId` | Doğrulanmadı | Başlık, spot, görsel, kategori, haber URL'si ve güncellenme tarihi |

Habertürk sayfalarının haber adetleri sayfa başına tekilleştirilmiştir; iki sayfanın toplam benzersiz haber sayısı olarak toplanmamalıdır. Manşet/modül kayıtları tekrarlanabilir.

### Diken, Medyascope, ShiftDelete

Doğrulanan liste uç noktaları:

```text
https://www.diken.com.tr/wp-json/wp/v2/posts?per_page=2&page=1
https://medyascope.tv/wp-json/wp/v2/posts?per_page=2&page=1
https://shiftdelete.net/wp-json/wp/v2/posts?per_page=2&page=1
```

Detay biçimi:

```text
/wp-json/wp/v2/posts/{id}?_embed=wp:featuredmedia,author
```

Üç yayında da detay yanıtında `author` ve `wp:featuredmedia` gömülü ilişkileri döndü.
Liste yanıtlarında `content.rendered`, `date_gmt`, `modified_gmt`, `author`,
`featured_media` ve `categories` alanları var. Yazar ID'si otomatik olarak haberi yazan
gazetecinin adı sayılmamalı; yayın hesabı olabilir.

Bu yapı RSS'e göre hem haber gövdesi hem görseller hem güncelleme takibi için daha iyi bir aday.
`content.rendered` HTML'dir: uygulamaya koymadan önce güvenli içerik bloklarına dönüştürülmeli;
video, shortcode ve özel eklenti bileşenleri düz metne indirgenince kaybolabilir.

Diken ve Medyascope haber HTML'leri ayrıca kendi JSON detay bağlantılarını ilan ediyor.
Her sitede `/wp-json` tahmin etmek yerine bu keşif bağlantılarını kullanmak daha doğru.
Veryansın TV de WordPress bağlantıları ilan etmişti; önceki denemede API 403 döndüğü için
onu çalışır API listesine dahil etmiyorum.

WordPress'in resmi belgeleri [keşif mekanizmasını](https://developer.wordpress.org/rest-api/using-the-rest-api/discovery/)
ve [listeleme/detay, sayfalama, tarih ve kategori alanlarını](https://developer.wordpress.org/rest-api/reference/posts/) açıklıyor.
Belgede yer alan tarih/kategori filtrelerinin bu üç sitedeki tüm kombinasyonları ayrıca test edilmedi.

### Habertürk: özel yayıncı API'si

Haber HTML'inde şu adres doğrudan `window.sidebarNewsApi` değişkeninde ilan ediliyor:

```text
https://htapi.haberturk.com/api/v1/haber/kategori/ht/gundem
```

`https://www.haberturk.com/js/default/news.js?v=482` dosyası bu değişkeni okuyup `fetch` ile
JSON'u alıyor. Endpoint tahmin edilmedi; sayfanın kullandığı adresten keşfedildi.

Yanıt yapısı:

```text
body.content.items.<modül>.items[]
  newsId, title, spot, absoluteUrl, category, image, updatedDateTime
references / diğer düğümler
  next
```

Yanıttaki `next` takip edildiğinde `/gundem/p2` de HTTP 200 döndü; onun yanıtında `/p3` var.
İlk yanıt yaklaşık 258 KB: bütün modülleri tekrar tekrar taşımak yerine sunucuda tekilleştirme
ve önbellekleme iyi olur. `updatedDateTime` örneği saat dilimi belirtmiyor; UTC kabul edilmemeli.

Önemli sınır: `spot`, haberin kendisi değildir. Bu araştırmada Habertürk **detay API'si bulunmuş
ve tam gövdesi alınmış** demiyorum. Listeyi buradan, detayı mevcut HTML/JSON-LD yolundan
almayı değerlendirebiliriz. Spor, ekonomi ve diğer kategorilerin hepsi ayrıca doğrulanmalı.

## API yanıtının sayfanın içinde bulunması

### DonanımHaber

`<script id="ng-state">` içinde Angular'ın sunucudan aktardığı HTTP yanıtı var.
Yanıtın ilan ettiği adres:

```text
https://api.donanimhaber.com/prod/web/api/News/GetNewsDetailPage
```

Gömülü yanıtın `Data.NewsDetailData.NewsDetail` alanında:

- `RawContent`: HTML temizlendikten sonra örnekte 4.178 karakter;
- `ContentList`: 7.236 karakterlik ham içerik alanı;
- `ContentImages`: 16 kayıt; bunların tamamının farklı ve editoryal görsel olduğu doğrulanmadı;
- `Title`, `ShortContent`, `Member`, `Category`, `CreateDateTime`, `DateUpdated`, `SourceUrl`;
- ayrıca `AiSummary`, `NarrationAudio` gibi alanlar.

Uç noktanın adresini bulduk, ancak bağımsız isteğin yöntemi/parametreleri/erişim koşulları
doğrulanmadı. En somut uygulanabilir yol şu an herkese açık HTML'deki JSON yanıtını okumak.
Bu yöntem sayfayı indirmeyi gerektirir; doğrudan hafif bir API çağrısı gibi sunulmamalı.
`AiSummary` veya ses kaydının alan olarak görünmesi bunları kullanma hakkı vermez;
mevcut uygulamanın kendi özet üretim akışına otomatik bağlanmamalı.

Angular'ın [resmi sunucu işleme belgesi](https://angular.dev/guide/ssr), sunucu yanıtlarının HTML
içinde aktarılıp istemcide tekrar kullanılabildiğini açıklar. Bu nedenle Network panelinde
haber gövdesini getiren ikinci bir çağrı her zaman görülmeyebilir.

### BBC Türkçe

`__NEXT_DATA__.props.pageProps.pageData` içinde `metadata`, `content`, `promo` ve başka alanlar var.
Örneğin `content` altında 89 metin düğümü ve toplam 11.170 karakter bulundu. Bu toplam başlık/görsel
altyazısı gibi düğümleri de içerebilir; doğrudan makale metni olarak birleştirilmemeli.
Blok türlerine göre paragraf, başlık, fotoğraf, altyazı, video ve bağlantı ayrıştırılmalı.

Bu, ayrı bir dış API'nin doğrulandığı anlamına gelmiyor. BBC'nin [açık kaynak Simorgh uygulaması](https://github.com/bbc/simorgh)
veri modelini anlamak için birincil teknik referans olabilir; yayıncının içerik kullanım koşulları ayrıca geçerlidir.

### Euronews Türkçe

`euronews-initial-server-data` script'i `window.getInitialServerData` fonksiyonu içinde JSON nesnesi taşıyor.
Örnekte `entities.article.plainText` 4.618 karakter; ayrıca başlık, spot (`leadin`), yazarlar,
canonical ve yayın/güncellenme zaman alanları var. Gömülü script'in tamamı saf JSON değil;
belirli kapsayıcıdan JSON nesnesi çıkarılmalı. `eval` kullanılmamalı.

Metin için iyi aday; görseller ve içerik sırası için diğer entity/HTML alanları ayrıca eşleştirilmeli.

## Henüz kullanılır diyemediğimiz yerler

- **Sözcü:** [API ana sayfası](https://apiv2.sozcu.com.tr/) HTTP 200 ve integration/webapp/mobileapp
  dokümantasyon bağlantıları veriyor. Üç bağlantı da bu testte HTTP 404 döndü. Çalışır haber
  listeleme/detay endpoint'i doğrulanmadı. API alan adı bulunması tek başına yeterli değil.
- **Halk TV:** incelenen JS'de sonsuz kaydırma, haber adresine `history=1` ve
  `X-Requested-With: XMLHttpRequest` ile **HTML** isteyen bir akış gösteriyor. Bu bir JSON haber API'si
  diye sınıflandırılmadı; çağrı bu çalışmada ayrıca denenmedi. İletişim formu API'si haber API'si değildir.
- **Webtekno:** haber sayfasındaki `/api/comments` yorumlar içindir; haber detayını sağladığı sonucuna varılmadı.
- **NTV, AA ve diğer kaynaklar:** framework/script izleri bir haber API'sinin dışarı açık olduğunu ispatlamıyor.
  Bu araştırma bunlar için kullanılır detay API'si sonucuna ulaşmadı; API yoktur sonucu da çıkarılmamalı.

## Pusula'ya uygulanacak yaklaşım

1. Diken/Medyascope/ShiftDelete için ortak bir WordPress sağlayıcısı: liste + ID ile detay + görsel/yazar ilişkileri.
2. Habertürk için özel liste sağlayıcısı; detay API'si doğrulanana kadar sayfa okuyucusu.
3. DonanımHaber/BBC/Euronews için ayrı gömülü veri okuyucuları.
4. Diğer kaynaklarda JSON-LD, kaynağa özel HTML ve RSS yedeği. API bozulunca kaynak tamamen kaybolmamalı.
5. Hepsi ortak bir `ArticleDetail` modeline yazmalı: içerik blokları, kaynak URL'si, yayın ve güncelleme tarihi,
   okuma yöntemi, gövde durumu (`full/partial/unavailable`) ve alınma zamanı. Bu durum sadece uzunluktan türetilmemeli.
6. Akış ve detay verisini sunucuda birleştirip önbellekleme: her telefondan her siteye yeniden istek atmayı azaltır;
   yayıncı şeması değiştiğinde düzeltme uygulama güncellemesi beklemez. Domain başına eşzamanlılık sınırı,
   429/5xx geri çekilmesi, tekrarları eleme ve son başarılı veriyi koruma gerekir.

Kabul kontrolü: Haber başlığı/URL/kimliği eşleşmeli, paragraf sırası ve son paragraf kaynakla karşılaştırılmalı,
galeri/canlı yayın/video/çok kısa haberler ayrıca denenmeli. `HTTP 200` veya uzun metin bulunması yeterli değildir.
Desteklenmeyen bileşen varsa kullanıcıya eksik metin tam haber diye gösterilmemeli.

Bu turda üretim veri akışı değiştirilmedi; araştırma ve tekrar çalıştırılabilir ölçüm aracı eklendi.

## Tekrar çalıştırma

Önce `tool/audit_news_sources.py` ile kaynak raporu ve geçici HTML'ler üretilmiş olmalı.
API aracı aynı izole Python ortamında çalıştırılır:

```powershell
& "$env:TEMP/pusula-news-audit-env/Scripts/python.exe" tool/audit_publisher_apis.py
```

Geçici HTML'ler silinmişse keşif envanteri eksik çıkar; önceki kaynak araştırmasını yeniden çalıştırmak gerekir.
Canlı yanıtlar değişebilir. Rapor haber gövdelerini veya oturum bilgilerini saklamaz; URL, alan adları,
HTTP durumu ve sayısal ölçümleri saklar. Üretim kullanımı öncesinde kaynak koşulları/robots politikası
ve izin gereksinimleri kaynak bazında tekrar değerlendirilmelidir.
