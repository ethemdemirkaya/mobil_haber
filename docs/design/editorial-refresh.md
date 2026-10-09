# Pusula — editoryal tasarım

Palet: kâğıt #F6F3EE, mürekkep #242321, marka #B32636. Koyu tema: #191816.
Başlık: Newsreader. Arayüz: Inter. Fontlar çevrimdışı çalışır; OFL lisansları assets/fonts içinde.

Maskot: gözlüklü yaşlı baykuş; yalnızca karşılama ve boş durumlarda. Haber görselleri gerçek kaynaklardan gelir.

Görseller yerleşik Imagegen aracıyla üretildi. Nihai promptlar:

## Maskot

Use case: illustration-story. Asset type: production transparent mascot for Pusula, a sophisticated Turkish editorial news reader. Create a single charming elderly owl librarian, NOT a human: small round owl with warm ivory and charcoal feathers, expressive kind eyes behind oversized round dark wire spectacles, bushy feather eyebrows and a tiny feather moustache suggesting a wise grandfather, a muted deep oxblood red scarf, holding a small folded newspaper with abstract ink lines (no legible text). Beautiful restrained hand drawn editorial illustration, crisp ink outlines, subtle screenprint texture, premium independent magazine character design, friendly and intelligent, not a toy, not 3D, no gradients, no glow. Full body, centered, ample transparent padding, feet visible. Limited palette ivory, ink charcoal, muted red #B32636. Actual transparent background, no scenery, no text, no watermarks.

## İkon keşfi

Use case: logo-brand. Asset type: final square app icon for Pusula Turkish editorial news app. A remarkably simple bold geometric compass emblem: deep oxblood red #B32636 circular ring with a clean angular north-east needle, small negative space at center. Warm off-white #F6F3EE full bleed background. Strict flat vector-like graphic, very sharp edges, visually balanced, generous 22 percent margins. Premium newspaper identity, timeless, legible at 24 pixels. Only one emblem centered. No letters, no text, no shadows, no gradients, no extra small tick marks, no mockup, no rounded-square border.

## Dosyalar

- assets/brand/wise-owl.png — şeffaf maskot
- assets/brand/compass-icon.png — üretilmiş logo keşfi
- assets/brand/pusula-mark.svg — ölçeklenebilir nihai marka, Flutter PusulaGlyph ile aynı geometri

## Akış

Karşılama → konular → kaynaklar → isteğe bağlı bildirim izni → Bugün.
Konular PreferencesProvider içinde saklanır ve kişisel akışa uygulanır. Kaynak seçimi mevcut RSS sistemini kullanır.
Bildirim izni hatırlatma oluşturmaz; saat ve konu Zamanlanmış Brifingler ekranında seçilir.
Manşetler kullanıcı kaydırdığında değişir. Açılışta yapay bekleme yoktur.

## Kontrol

Açık/koyu tema, 320/390 piksel telefon genişliği ve büyütülmüş yazıyla karşılama ve konu seçimi kontrol edilir.
Haber akışı, okuma, arama, kayıtlar, çapraz kaynaklar ve ayarlar ortak tema bileşenlerini kullanır.


## İnceleme bulguları ve uygulanan değişiklikler

- Karşılama ve kişiselleştirme, ortak editoryal tipografi ve sıcak yüzeyler kullanır.
- Bugün: kategori filtresi üstte; manşetler kullanıcı kontrolünde; sesli brifing kartında kulaklıklı maskot.
- Haber detayı: seçilebilir kaynak önizlemesi; kaynak yer tutucularına açıklayıcı boş durum; aynı genişlikte sesli özet, dil değerlendirmesi ve soru kartları.
- Dil değerlendirmesi: taşan başlık/etiket satırı ve iç içe kenar boşlukları kaldırıldı. Ayrıntılar açılır alanda; koyu temada durum renkleri okunabilir.
- Durum çubuğu: haber görseli kaydırılınca açık zeminde koyu sistem simgelerine geçer.
- Kaynak bağlantısı: büyük yazıda adres alt satırda; kelimeler dar sütunda bölünmez.
- Navigasyon: Tabler çizgi ikonları, açık seçili durum, erişilebilir sekme etiketleri ve 99+ kayıt rozeti.
- Splash: 650 ms pusula dönüşü ve solma. Tercih yüklemesiyle birlikte çalışır, haber yüklemesini beklemez; sistemin animasyonu azaltma tercihini izler.
- Maskot: okuyan, dinleyen ve merak eden üç poz. Karşılama, boş durumlar, ana sayfa brifingi ve haber soruları içinde.

## Doğrulama

- flutter analyze: sorun yok.
- flutter test: 57 test geçti; 10 tasarım/etkileşim testi dahil.
- 320/390 piksel genişlik; açık/koyu tema; %150 yazı ölçeği. Haber araçları, kaynak bağlantısı ve beş navigasyon hedefi kontrol edildi.
- Screenshot dosyaları gözle incelendi. detail-*.png ve navigation-large-type.png test verisi içerir.
- Android x86_64 debug APK derlendi ve emülatöre uygulama verileri korunarak kuruldu. iOS kaynakları hazır; Windows ortamında iOS derlemesi yapılmadı.
- Mevcut news_provider testleri zaman zaman kapanmış veritabanı mesajı yazıyor; testlerin tamamı geçiyor. Yeni görsel testler ağ veya gerçek veritabanına bağımlı değil.

Marka varlıklarını yeniden paketlemek için: flutter test test/editorial_design_test.dart, ardından ./tool/package_brand.ps1.

## İkon paketi

flutter_tabler_icons 1.43.0 (MIT): https://pub.dev/packages/flutter_tabler_icons
Ortak glyph kataloğu: lib/core/theme/app_icons.dart. Paket fontu görsel testlerde de yüklenir.

## Yeni maskot pozları — imagegen

Referans: assets/brand/wise-owl.png. Çıktılar şeffaf arka planla üretildi; orijinal dosya korundu.

Dinleme pozu — assets/brand/wise-owl-listening.png:

> Create a single new pose of this exact mascot for a professional Turkish editorial news app. Preserve the owl character's recognizable elderly grandfather face, round spectacles, cream and charcoal ink engraving style, red scarf, proportions, and subtle hand printed texture. Full body isolated on transparent background with generous clear padding. Pose: wearing understated charcoal over ear headphones, eyes gently closed listening happily, wings holding its folded newspaper against chest. Warm, wise and cute, editorial rather than glossy cartoon. No words, no background, no shadow rectangle, no extra objects or characters. Red scarf only color accent.

Merak pozu — assets/brand/wise-owl-curious.png:

> Create one new pose of this exact elderly wise owl news app mascot. Preserve its round spectacles, grandfather eyebrows, charcoal engraving lines, cream feather colors and deep red scarf. Full body centered with clear generous padding on transparent background. Curious pose: looking toward viewer with friendly raised eyebrow, one wing resting on chin thoughtfully, other holding a small closed newspaper under arm. No headphones. Same restrained sophisticated vintage editorial ink illustration, warm and cute, no glossy 3D, no text, no background or extra characters.
