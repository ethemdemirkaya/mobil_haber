<div align="center">

# 🧭 Pusula

**Yapay zeka destekli, sesli özetli Türkçe haber okuyucu**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2024+-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![OpenRouter](https://img.shields.io/badge/AI-OpenRouter-7C3AED)](https://openrouter.ai)
[![CI](https://github.com/ethemdemirkaya/mobil_haber/actions/workflows/ci.yml/badge.svg)](https://github.com/ethemdemirkaya/mobil_haber/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

*Haberleri oku, dinle, anla — yapay zekayla güçlendirilmiş.*

</div>

---

## Ekran Görüntüleri

```
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│  🏠  Ana Sayfa       │  │  📰  Haber Detay     │  │  🎙  Günlük Brifing  │
│─────────────────────│  │─────────────────────│  │─────────────────────│
│  ☀️  Günün Özeti     │  │  [Haber Görseli]    │  │  ┌──────────────┐   │
│  ─────────────────  │  │                     │  │  │  🎵  Oynatıcı │   │
│  [🌐] Teknoloji ↗   │  │  Başlık: Lorem...   │  │  │  ─────────── │   │
│  2dk önce · Habertü  │  │  2dk önce           │  │  │  ⏮  ▶  ⏭    │   │
│                     │  │                     │  │  └──────────────┘   │
│  [🌐] Spor ↗        │  │  Lorem ipsum dolor  │  │                     │
│  5dk önce · NTV Spo  │  │  sit amet...        │  │  Başlık 1           │
│                     │  │                     │  │  ▓▓▓░░░░░░░         │
│  [🌐] Gündem ↗      │  │  ┌─ AI'ya Sor ─┐   │  │  Başlık 2           │
│  8dk önce · CNN Türk │  │  │ ✨ BETA     │   │  │  ░░░░░░░░░░         │
│                     │  │  │ Neden önemli│   │  │                     │
│  ─────────────────  │  │  └─────────────┘   │  │  Hız: 1.0x  Vol: █  │
│  [Shimmer loading]  │  │                     │  │                     │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘

┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│  🔍  Arama           │  │  ⚙️  Ayarlar          │  │  🧭  Kaynak Seçici  │
│─────────────────────│  │─────────────────────│  │─────────────────────│
│  ┌─────────────┐    │  │  Tema                │  │  Tüm Kaynaklar (56) │
│  │ 🔍 Ara...   │    │  │  ● Otomatik          │  │─────────────────────│
│  └─────────────┘    │  │  ○ Açık              │  │  [BB] BBC Türkçe  ✓ │
│                     │  │  ○ Koyu              │  │  [HT] Hürriyet    ✓ │
│  Son Aramalar       │  │                     │  │  [NT] NTV         ✓ │
│  · yapay zeka       │  │  Yapay Zeka          │  │  [CR] CNN Türk    ✓ │
│  · Türkiye          │  │  Model: Claude Haiku │  │  [BK] Bianet      ✓ │
│  · ekonomi          │  │  Dil: Türkçe         │  │  [AA] AA          ✓ │
│                     │  │                     │  │  [IN] Independent ✓ │
│  Sonuçlar           │  │  Sesli Okuma         │  │  + 49 daha...       │
│  ─────────────────  │  │  Motor: ElevenLabs   │  │                     │
│  [🌐] Haber başlığı │  │  Ses: Adam           │  │  [Kaydet]           │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
```

---

## Özellikler

### Haber Akışı
- **56 kaynak** — ulusal, ekonomi, teknoloji, spor ve uluslararası Türkçe yayınlar
- **Gerçek zamanlı RSS** — backend yok, doğrudan kaynaklardan paralel çekim
- **Çapraz bakış (olay kümeleme)** — aynı olayı işleyen farklı kaynakları cihaz
  üzerinde gruplar: Türkçe F5 kök çıkarımı + TF-IDF + artımlı centroid kümeleme
- **Gündem** — birden çok kaynağın şu an işlediği olaylar; zamanla sönümlenen
  skor (her kaynak 6 saatte yarıya iner)
- **Sana Özel** — okuma geçmişinden öğrenen sıralama + MMR çeşitlilik
  (filtre balonunu azaltır), her öneride kısa gerekçe
- **Kelime filtresi** — istemediğin kelimeleri içeren haberleri gizle
- **Offline okuma** — son akış ve okuma geçmişi SQLite'ta

### Yapay Zeka

| Özellik | Açıklama |
|---|---|
| **Haber özeti** | Yalnızca haber metnine dayalı 2-3 madde; metin yetersizse özet üretilmez |
| **Tam metin çıkarımı** | RSS sadece kısa açıklama veriyorsa makale sayfasından gövde paragrafları çıkarılır |
| **AI'ya sor** | Her cevap "haber metnine dayanıyor" / "genel bilgi — doğrulayın" diye etiketlenir |
| **Yönlülük analizi** | LLM değerlendirmesi + cihazda kural tabanlı dil sinyalleri; uyumlarına göre güven düzeyi |

> **Not:** AI özellikleri [OpenRouter](https://openrouter.ai) üzerinden çalışır.
> Varsayılan model: `openai/gpt-oss-20b:free` (ücretsiz katman).
> Kullanıcı kendi API anahtarını girerek istediği modeli seçebilir.

### Sesli Okuma (TTS)

Üç farklı motor katmanıyla aşamalı kalite/maliyet dengesi:

```
Sistem TTS  ──→  OpenAI TTS  ──→  ElevenLabs TTS
(Ücretsiz)       (Düşük maliyet)   (En doğal ses)
Google/Android   tts-1 / tts-1-hd  Multilingual v2
                 Nova, Alloy, Echo  Adam, Rachel, Josh
```

- **Günlük Brifing** — Seçili kaynaklardan derlenen haberler otomatik seslendirilir
- **Zamanlanmış brifing** — "Her sabah 07:00'de spor brifingini oku"
- **Arka plan oynatma** — Lock screen + bildirim paneli medya kontrolü
- **Hız ayarı** — 0.5x → 2.0x (sistem), 0.7x → 1.2x (ElevenLabs)
- **Uyku zamanlayıcısı** — 15/30/60 dakika sonra otomatik durdur

### Diğer
- **Yer imleri** — Tam makale snapshot'ı, kaynak kapanmış olsa bile okunabilir
- **Okuma geçmişi** — Hangi haberleri okudun, ne zaman
- **Push bildirim** — Firebase Cloud Messaging üzerinden son dakika
- **Karanlık / Açık / Otomatik** tema
- **Hava durumu widget** — Ana sayfada mini widget
- **Piyasalar widget** — Döviz ve borsa özet

---

## Mimari

```
lib/
├── app.dart                    # MaterialApp + router
├── main.dart                   # Bootstrap (TTS, bildirim, cache warmup)
│
├── core/
│   ├── ai/
│   │   └── openrouter_client.dart     # OpenRouter HTTP istemcisi
│   ├── notifications/                  # Push + zamanlanmış bildirim
│   ├── theme/                          # Renk paleti, tipografi
│   ├── tts/                            # AudioSession, AudioHandler
│   ├── net/                            # Paylaşılan HTTP istemcisi
│   └── utils/                          # Türkçe metin, HTML, tarih yardımcıları
│
├── data/
│   ├── local/                          # SQLite: haber cache, AI cache, okuma geçmişi
│   ├── models/                         # Article, NewsSource, BiasReport, QaAnswer…
│   └── repositories/
│       ├── rss_news_service.dart        # RSS/Atom parser + feed sağlık kontrolü
│       ├── category_classifier.dart     # Kelime + Türkçe ek tabanlı kategori
│       ├── news_cluster_service.dart    # TF-IDF + centroid olay kümeleme
│       ├── personalization_service.dart # İlgi profili + MMR çeşitlilik
│       ├── article_text_extractor.dart  # Makale sayfasından gövde metni
│       ├── language_signal_analyzer.dart# Kural tabanlı yönlü dil sinyalleri
│       ├── ai_summary_service.dart      # AI özet
│       ├── daily_briefing_service.dart  # Brifing metin üretici
│       ├── openai_tts_service.dart      # OpenAI TTS
│       ├── elevenlabs_tts_service.dart  # ElevenLabs TTS
│       └── og_image_resolver.dart       # Open Graph görsel çekici
│
├── providers/                          # Provider state management
│   ├── news_provider.dart              # Haber akışı + filtre
│   ├── ai_settings_provider.dart       # AI ayarları, özet/bias/Q&A
│   ├── tts_settings_provider.dart      # Sesli okuma motoru ve ses ayarları
│   ├── bookmark_provider.dart          # Yer imi snapshot'ı
│   └── …
│
├── screens/
│   ├── home/                           # Ana sayfa
│   ├── detail/                         # Haber detay + AI işlevler
│   ├── briefing/                       # Sesli brifing oynatıcı
│   ├── settings/                       # Tüm ayar ekranları
│   └── onboarding/                     # İlk kurulum akışı
│
└── widgets/                            # Paylaşılan UI bileşenleri
    ├── article_card.dart
    ├── bias_indicator.dart             # Yönlülük analiz kartı
    ├── source_logo.dart                # Favicon fallback zinciri
    └── …
```

**Temel mimari kararlar:**

| Karar | Tercih | Sebep |
|---|---|---|
| State management | `provider` | Basit, yeterli, Flutter-native |
| RSS parsing | Doğrudan istemci | Backend maliyeti yok |
| AI gateway | OpenRouter | 100+ model, tek API |
| Yerel veri | `sqflite` | Haber cache, sınırlı AI cache (300 kayıt / 30 gün), okuma geçmişi |
| Görsel cache | `cached_network_image` | Disk + memory, LRU |
| TTS cache | SHA-256 hash → dosya | Aynı metin tekrar üretilmez |
| Secrets | Gradle `generateSecrets` → gitignored | Git'e girmez |

---

## Kurulum

### Gereksinimler
- Flutter `^3.x` / Dart `^3.11`
- Android API 24+ (Android 7.0)
- Java 17

### 1. Repoyu klonla

```bash
git clone https://github.com/ethemdemirkaya/pusula.git
cd pusula
flutter pub get
```

### 2. API anahtarlarını ayarla

```bash
# Şablonu kopyala
cp .env.json.example .env.json
```

`.env.json` dosyasını düzenle:

```json
{
  "OPENROUTER_API_KEY": "sk-or-v1-..."
}
```

> **OpenRouter** ücretsiz katman mevcut — [openrouter.ai/keys](https://openrouter.ai/keys)
> AI özetleme, soru-cevap ve yönlülük analizi için gerekli.
> OpenAI TTS ve ElevenLabs TTS opsiyonel — uygulama ayarlarından girilebilir.

### 3. Firebase (opsiyonel — push bildirim için)

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Firebase olmadan push bildirim devre dışı kalır; diğer her şey çalışır.

### 4. Çalıştır

```bash
# Debug
flutter run

# Release APK (mimari başına ayrı)
flutter build apk --release --split-per-abi

# Tek APK (tüm mimariler)
flutter build apk --release
```

> `.env.json` ek parametre gerektirmez — Gradle `preBuild` hook'u otomatik okur.

---

## AI Özelliği Detayları

### Soru-Cevap Sistemi (3 Katmanlı)

```
Kullanıcı sorusu geldiğinde AI önce sınıflandırır:

  Tip A — Metinden yanıtlanabilir
  └→ "Kim öldü?", "Nerede oldu?", "Ne zaman?"
     → Yalnızca haber metnindeki bilgiyle yanıt

  Tip B — Bağlam / Arka plan sorusu
  └→ "Bu neden önemli?", "Arkaplanı nedir?", "Sonuçları ne olabilir?"
     → Genel bilgiyle zenginleştirilmiş yanıt

  Tip C — Alakasız
  └→ "Bugün hava nasıl?", "Bana şiir yaz"
     → Nazikçe reddeder
```

### Yönlülük Analizi Skorları

| Skor | Bant | Renk |
|------|------|------|
| 0–25 | Nötr | Yeşil |
| 26–50 | Hafif | Sarı |
| 51–75 | Belirgin | Turuncu |
| 76–100 | Güçlü | Kırmızı |

---

## Haber Kaynakları

<details>
<summary>56 kaynak göster</summary>

**Genel / Ulusal**
Anadolu Ajansı · TRT Haber · Sabah · Sözcü · Hürriyet · Milliyet · Cumhuriyet ·
Habertürk · CNN Türk · NTV · Yeni Şafak · Diken · Gazete Duvar · Artı Gerçek ·
Karar · Halk TV · TELE1 · OdaTV · Aydınlık · Yeniçağ · Veryansın TV · Medyascope ·
Gerçek Gündem · Vatan · Türkiye Gazetesi · İnternethaber · Nethaber · Posta ·
Akşam · Takvim · A Haber · Star · Bianet · Mynet · Haber Global · Habertürk Genç

**Uluslararası**
BBC Türkçe · DW Türkçe · Euronews Türkçe · Independent Türkçe · Daily Sabah ·
Hürriyet Daily News · AA English

**Ekonomi**
Investing.com Türkçe · Bloomberg HT · Dünya Gazetesi · Bigpara · Ekonomim

**Teknoloji**
Webrazzi · ShiftDelete.Net · Donanım Haber · Webtekno · CHIP Online · Tamindir

**Spor**
Fotomaç · A Spor

Bazı kaynakların public RSS'i zaman zaman kırılabiliyor; durumlarını
**Ayarlar › Tanılama › Kaynak sağlığı** ekranından görebilirsin. Tam liste:
[`news_source.dart`](lib/data/models/news_source.dart).

</details>

---

## Katkı

Pull request'ler memnuniyetle karşılanır. Büyük değişiklikler için önce bir issue açın.

```bash
git checkout -b feat/yeni-ozellik
flutter analyze
flutter test
```

Her PR'da GitHub Actions `flutter analyze` ve `flutter test` çalıştırır.

**Commit formatı:** `feat(scope): kısa açıklama` (Türkçe tercih edilir)

---

## Lisans

MIT © [Ethem Demirkaya](https://github.com/ethemdemirkaya)

---

<div align="center">
  <sub>Pusula — Haberlerde yönünü bul.</sub>
</div>
