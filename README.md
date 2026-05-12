<div align="center">

# 🧭 Pusula

**Yapay zeka destekli, sesli özetli Türkçe haber okuyucu**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2024+-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![OpenRouter](https://img.shields.io/badge/AI-OpenRouter-7C3AED)](https://openrouter.ai)
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
│  ┌─────────────┐    │  │  Tema                │  │  Tüm Kaynaklar (42) │
│  │ 🔍 Ara...   │    │  │  ● Otomatik          │  │─────────────────────│
│  └─────────────┘    │  │  ○ Açık              │  │  [BB] BBC Türkçe  ✓ │
│                     │  │  ○ Koyu              │  │  [HT] Hürriyet    ✓ │
│  Son Aramalar       │  │                     │  │  [NT] NTV         ✓ │
│  · yapay zeka       │  │  Yapay Zeka          │  │  [CR] CNN Türk    ✓ │
│  · Türkiye          │  │  Model: Claude Haiku │  │  [BK] Bianet      ✓ │
│  · ekonomi          │  │  Dil: Türkçe         │  │  [AA] AA          ✓ │
│                     │  │                     │  │  [IN] Independent ✓ │
│  Sonuçlar           │  │  Sesli Okuma         │  │  + 35 daha...       │
│  ─────────────────  │  │  Motor: ElevenLabs   │  │                     │
│  [🌐] Haber başlığı │  │  Ses: Adam           │  │  [Kaydet]           │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
```

---

## Özellikler

### Haber Akışı
- **42+ Türkçe kaynak** — Hürriyet, Cumhuriyet, BBC Türkçe, NTV, CNN Türk, Sözcü, Bianet, T24 ve daha fazlası
- **Gerçek zamanlı RSS** — Backend yok, doğrudan kaynaklardan çekme
- **Kişiselleştirilmiş feed** — Kategori ve kaynak bazlı özelleştirme
- **Kümeleme** — Aynı konuyu işleyen farklı kaynaklardan haberleri bir araya getirir
- **Kelime filtresi** — İstemediğin kelimeleri içeren haberleri gizle
- **Offline okuma** — Önbellek yönetimiyle internet olmadan da erişim

### Yapay Zeka

| Özellik | Açıklama |
|---|---|
| **Haber özeti** | Uzun haberleri 3-4 cümleye indirir |
| **AI'ya sor** | Haber hakkında soru-cevap: arkaplan, önem, bağlam |
| **Yönlülük analizi** | Manşet dilini tarafsızlık için 0-100 skor + gerekçe |
| **Gündem rozeti** | "Bu haber neden önemli?" — tek cümlelik bağlam |
| **Çapraz bakış** | Aynı habere farklı kaynaklar ne diyor? |

> **Not:** Tüm AI özellikleri [OpenRouter](https://openrouter.ai) üzerinden çalışır.
> Varsayılan model: `anthropic/claude-3.5-haiku` — hızlı, ucuz, Türkçe güçlü.
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
│   └── utils/                          # Tarih formatlama
│
├── data/
│   ├── models/                         # Article, NewsSource, BiasReport…
│   └── repositories/
│       ├── rss_news_service.dart        # RSS/Atom parser (xml paketi)
│       ├── ai_summary_service.dart      # AI özet + soru-cevap mantığı
│       ├── daily_briefing_service.dart  # Brifing metin üretici
│       ├── openai_tts_service.dart      # OpenAI TTS HTTP istemcisi
│       ├── elevenlabs_tts_service.dart  # ElevenLabs TTS HTTP istemcisi
│       ├── og_image_resolver.dart       # Open Graph görsel çekici
│       └── news_cluster_service.dart    # Kümeleme mantığı
│
├── providers/                          # Provider state management
│   ├── news_provider.dart              # Haber akışı + filtre
│   ├── ai_settings_provider.dart       # AI + TTS ayarları
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
<summary>42 aktif kaynak göster</summary>

**Genel / Ulusal**
Hürriyet · Cumhuriyet · Sözcü · Sabah · Milliyet · CNN Türk · NTV · T24 · Bianet · Gazete Duvar · Independent Türkçe · Diken · Medyascope · Artı Gerçek · Sendika.org

**Teknoloji**
Webtekno · Shiftdelete · Technopat · Donanımhaber · Log

**Spor**
NTV Spor · Sporx · A Sporu

**Ekonomi**
Dünya · Para · Ekohaber · Bloomberg Türkiye

**Uluslararası (Türkçe)**
BBC Türkçe · Deutsche Welle Türkçe · VOA Türkçe · Euronews Türkçe

**Haber Ajansları**
AA (Anadolu Ajansı) · DHA

</details>

---

## Katkı

Pull request'ler memnuniyetle karşılanır. Büyük değişiklikler için önce bir issue açın.

```bash
git checkout -b feat/yeni-ozellik
flutter analyze
flutter test
```

**Commit formatı:** `feat(scope): kısa açıklama` (Türkçe tercih edilir)

---

## Lisans

MIT © [Ethem Demirkaya](https://github.com/ethemdemirkaya)

---

<div align="center">
  <sub>Pusula — Haberlerde yönünü bul.</sub>
</div>
