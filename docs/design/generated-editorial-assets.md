# Yeni açılış ve editoryal görseller

2026-10-10 — Built-in imagegen ile üretildi. Referans maskot: `assets/brand/wise-owl.png`. Orijinal çıktılar `C:/Users/ethem/.codex/generated_images/01a1225d-afb8-7762-b0b9-a310f37f248f/` altında korundu.

| Asset | Kullanıldığı yer | Orijinal çıktı |
|---|---|---|
| `wise-owl-welcome.png` | Android/iOS yerel açılış ve Flutter selamlama animasyonu | `exec-62dbff9e-5015-4eeb-9160-d4f31bc1117f.png` |
| `editorial-briefing.png` | Ana sayfa brifing bağlantısı ve brifing hazırlama ekranı | `exec-cefb433b-6523-418f-bc58-9dfec71e38c7.png` |
| `editorial-saved.png` | Kayıtlı haberlerin boş durumu | `exec-7d60e77d-6706-41e4-9525-8290c3117cd4.png` |
| `editorial-perspectives.png` | Çapraz Bakış boş durumu ve bilgi sayfası | `exec-c685d841-e854-49d4-80cd-c9dee84fcc33.png` |

## Promptlar

### Selamlama maskotu

Use case: identity-preserve. Create a welcoming splash-screen pose of the exact elderly editorial owl mascot in the reference. Keep the same spectacles, cream feathers, ink engraving strokes, red scarf and recognizable grandfather face. Full body centered, front facing, one wing lifted in a small friendly wave, other wing holding a neatly folded newspaper. Gentle smile, intelligent and calm. A strong readable silhouette suitable for a small Android launch icon. Generous transparent padding on all sides; no crop. No background, no words or letters, no logo, no glow, no glossy rendering. This is one character, one still illustration that will be animated in Flutter.

### briefing

Use case: illustration-story. Asset type: decorative mobile news reader illustration for Pusula. Subject: a ceramic coffee cup, understated over-ear headphones and a neatly folded morning newspaper, arranged as a compact calm still life. Style: refined vintage newspaper engraving, charcoal ink crosshatching, warm cream paper and muted warm wood, one deep red (#B32636) accent, matching an elderly owl editorial mascot's printed illustration world but NO mascot in this image. Clear restrained silhouette readable at 120 pixels, centered compact composition with generous clear padding. Transparent background. No words, no readable letters, no logos, no watermark, no scene background, no glow, no gradients, no glossy 3D, no photorealistic news events.

### saved

Use case: illustration-story. Asset type: decorative mobile news reader illustration for Pusula. Subject: a small elegant wooden newspaper rack holding three folded newspapers, a single deep red bookmark draped over the front newspaper. Style: refined vintage newspaper engraving, charcoal ink crosshatching, warm cream paper and muted warm wood, one deep red (#B32636) accent, matching an elderly owl editorial mascot's printed illustration world but NO mascot in this image. Clear restrained silhouette readable at 120 pixels, centered compact composition with generous clear padding. Transparent background. No words, no readable letters, no logos, no watermark, no scene background, no glow, no gradients, no glossy 3D, no photorealistic news events.

### perspectives

Use case: illustration-story. Asset type: decorative mobile news reader illustration for Pusula. Subject: three distinct folded newspapers arranged as a clear open fan, each showing different abstract column layouts about one shared circular illustration, a visual metaphor for different perspectives. Style: refined vintage newspaper engraving, charcoal ink crosshatching, warm cream paper and muted warm wood, one deep red (#B32636) accent, matching an elderly owl editorial mascot's printed illustration world but NO mascot in this image. Clear restrained silhouette readable at 120 pixels, centered compact composition with generous clear padding. Transparent background. No words, no readable letters, no logos, no watermark, no scene background, no glow, no gradients, no glossy 3D, no photorealistic news events.

## Uygulama ve doğrulama

Flutter selamlama animasyonu ilk kare rasterize edildikten sonra başlar ve 1200 ms sürer; hareket azaltma ayarı açıkken hazır olan hedef ekrana doğrudan geçilir. Böylece yavaş bir ilk açılışta animasyon yerel splash arkasında tamamlanmaz. Haberler ve sağlayıcılar animasyon arkasında hazırlanır. Ses servisleri ilk Flutter karesini engellemez; brifing aynı hazırlık Future'ını bekler.

Yerel açılış görseli 288 dp tuval üzerinde, Android ikon maskesine sığacak boşlukla Flutter testinden dışa aktarılır. `tool/package_brand.ps1` Android bitmap ve iOS 1x/2x/3x karşılıklarını paketler. Android 12+ sistem maskesi için [resmi splash yönergeleri](https://developer.android.com/develop/ui/views/launch/splash-screen) dikkate alındı. Yerel ekran sabit maskottur; hareket Flutter katmanındadır.

Açık/koyu tema, 320 dp genişlik ve %200 yazı boyutu, animasyonun tamamlanması ve hareket azaltma davranışı widget testleriyle kontrol edildi. 64 test geçti; ilk kare zamanlaması düzeltmesinden sonra ilgili 17 tasarım testi tekrar geçti. Flutter analizi temiz; Android x64 debug paketi mevcut veriler korunarak emülatöre kuruldu.

Yerel açılış ve Flutter selamlaması emülatörde kaydedilip kareleri incelendi. [Kısa geçiş videosu](screenshots/launch-preview.mp4), [yerel açılış](screenshots/native-launch-emulator.png), [Flutter selamlama karesi](screenshots/launch-animation-emulator.png). 1200 ms yalnızca Flutter animasyonunun süresidir; debug emülatörün motor başlatma süresini içermez.

iOS varlıkları güncellendi; bu Windows ortamında iOS derlemesi yapılmadı.
