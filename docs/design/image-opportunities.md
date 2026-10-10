# Pusula için 10 görsel fırsatı

Bunlar imagegen ile üretilebilecek adaylardır. 2, 4 ve 9 numaralı görseller ile açılış için selamlama maskotu üretildi ve uygulamaya eklendi. Dosyalar, kullanılan promptlar ve yerleşimler [üretim kaydında](generated-editorial-assets.md). Diğerleri ihtiyaç oluştuğunda kullanılacak adaylar olarak duruyor.

Ortak sanat yönü: sıcak kâğıt, mürekkep gravür, az miktarda Pusula kırmızısı (#B32636), sade siluetler. Mevcut baykuşla aynı editoryal dünya. İşlevsel ikonlar Tabler olarak kalır. Görsellerin içine yazı gömülmez; Türkçe açıklamalar uygulamanın ölçeklenebilir metinleri olur. Koyu tema için şeffaf çevre ve okunaklı krem vurgular. Haber fotoğrafı yerine yapay olay görseli kullanılmaz.

| # | Yer | Görsel fikri | İşlev / gösterim |
|---|---|---|---|
| 1 | Karşılama | Katlanmış gazete üzerinde küçük pusula | Mevcut maskota alternatif yatay hero; ikisi aynı anda değil. |
| 2 | Günlük brifing girişi | Kahve, kulaklık ve sabah gazetesi | Dinleme alışkanlığını anlatan küçük bölüm görseli. |
| 3 | Kaynak seçimi açıklaması | Farklı baskıları olan üç gazete | Tek olayın farklı kaynaklardan izlenmesini anlatır; sahte kaynak logosu içermez. |
| 4 | Kayıtlı haberler boş durumu | Okuma ayracı ve küçük gazete rafı | Kaydetme işlevini anlatır; ilk kayıttan sonra görünmez. |
| 5 | Arama sonucu bulunamadı | Katlanmış harita üzerinde büyüteç | Yeni kelime denemeyi teşvik eder; hata veya alarm simgesi değildir. |
| 6 | Çevrimdışı haberler boş durumu | Sessiz taşınabilir radyo ve kapalı gazete | Bağlantı yokken kısa açıklama ve yeniden dene eylemine eşlik eder. |
| 7 | Bildirim tanıtımı | Sabah ışığında masa saati | Hatırlatmanın nedenini açıklar; izin verilmiş gibi başarı işareti içermez. |
| 8 | Okuma geçmişi boş durumu | Açık defter ve birkaç kâğıt ayraç | Okunan haberlerin burada bulunacağını anlatır. |
| 9 | Çapraz Bakış ilk kullanım | Aynı merkeze dönük üç ayrı gazete penceresi | Farklı bakışları karşılaştırma fikrini tanıtır; içerik yüklendikten sonra geri çekilir. |
| 10 | Hakkında / marka hikâyesi | Pusula, gözlük ve editör masası | Uygulamaya karakter verir; haber okuma akışını meşgul etmez. |

## Imagegen üretim promptları

Her satır için aşağıdaki ortak prompt ile ilgili nesne kompozisyonu birleştirilir. Bunlar üretim önerileridir; üretilmiş asset dosyalarına referans değildir.

> Use case: illustration-story. Asset type: decorative illustration for a Turkish editorial news reader called Pusula. Create [SUBJECT]. Style: refined newspaper engraving, restrained ink crosshatching, warm cream highlights, charcoal linework and one small deep red (#B32636) accent. Simple legible composition at small mobile sizes, generous clear padding, transparent background. No words, no letters, no logos, no watermark, no gradients, no glossy 3D, no photorealistic news events. All explanatory UI text will be rendered separately in Flutter.

SUBJECT değerleri:

1. a small compass resting on one folded newspaper, wide horizontal composition
2. a ceramic coffee cup beside understated headphones and a folded morning newspaper
3. three distinct folded newspapers arranged as a calm fan, each with different abstract column layouts
4. a modest shelf holding folded newspapers with a deep red reading bookmark
5. a magnifying glass resting on a small folded paper map
6. a silent portable radio beside a closed newspaper, calm reassuring mood
7. a simple analog table clock with a small rising sun motif behind it
8. an open reading journal with a few paper bookmarks
9. three newspaper windows arranged around one central blank circular space, visual metaphor for different perspectives
10. a small editor desk still life with round spectacles, a compass and a neatly folded newspaper

## Yaşlı kullanıcılar için düzenleme

Haber sonundaki bağımsız kartlar kaldırıldı. Okuma yardımı tek bir bölüm: belirgin sesli dinleme düğmesi, 64 dp asgari eylem satırları, 18 sp etiketler, satır içinde okunabilir özet, isteğe bağlı dil analizi. %200 yazıda dekoratif maskot gizlenir; eylemler ve açıklamalar büyümeye devam eder. Uygulama kullanıcı testi yapılmış gibi bir uygunluk iddiası taşımaz; widget kontrolleri gerçek kullanıcı denemesinin yerine geçmez.

Referans: https://www.w3.org/WAI/older-users/developing/ ve https://www.w3.org/WAI/WCAG21/Understanding/resize-text
