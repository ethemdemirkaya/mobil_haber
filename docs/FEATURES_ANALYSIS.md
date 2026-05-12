# Özellik Analizi & Yol Haritası

> Tarih: 2026-05-07
> Durum: Phase-1 + Phase-2 + Dış kaynak entegrasyonu + API araştırması tamamlandı.
> Bu doküman, **bir sonraki iterasyonda eklenebilecek özellikleri** sistematik olarak listeler.

## 1. Mevcut durum (özet)

| Alan | Durum |
|---|---|
| Tema (light/dark/system, S/M/L font) | ✅ |
| Onboarding (3 sayfa) | ✅ |
| Ana akış (Home/Detail/Search/Bookmarks/Settings) | ✅ |
| Provider'lar (Theme, News, Bookmark, Search, ReadingHistory, Onboarding, Preferences, External) | ✅ |
| Hero animasyonlar, A-/A+, share_plus, scroll progress | ✅ |
| Featured carousel auto-scroll, "Devam et" satırı | ✅ |
| Bookmarks: filtre/sıralama/grup | ✅ |
| Kategori detay: 5 sıralama | ✅ |
| Settings alt sayfaları (NotifPrefs/DataUsage/About/ReadingHistory) | ✅ |
| Dış kaynaklar: 11 sağlayıcı (RSS×8 + GDELT + HN + 3 keyed) | ✅ |
| Aggregate + Source seçici LiveNewsScreen | ✅ |

## 2. Aday özellikler — kategoriler

### A. Engagement / okuma deneyimi (yüksek UX etkisi)
| # | Özellik | Etki | Efor | Önerilir? |
|---|---------|------|------|-----------|
| A1 | Read/unread badge — listede okunmuş haberler için solgun + "Okundu" rozeti | ⭐⭐⭐⭐ | Düşük | **EVET** |
| A2 | Reading progress restore — detay ekranı tekrar açıldığında en son scroll konumuna dön | ⭐⭐⭐⭐ | Orta | **EVET** |
| A3 | TL;DR summary card — detayda öne çıkan 2-satır özet (mevcut summary'i kart olarak vurgula) | ⭐⭐⭐ | Düşük | **EVET** |
| A4 | Reading mode (sepia) — distraction-free, kremrengi arkaplan, geniş satır yüksekliği | ⭐⭐⭐⭐ | Orta | **EVET** |
| A5 | Article highlighting / notes — metin işaretleme, kişisel not | ⭐⭐ | Yüksek | Phase-3 |
| A6 | TTS okuma — sesli okuma | ⭐⭐⭐ | Yüksek | Phase-3 |
| A7 | Translate (TR↔EN) | ⭐⭐ | Yüksek | Phase-3 |

### B. Discovery / personalisation
| # | Özellik | Etki | Efor | Önerilir? |
|---|---------|------|------|-----------|
| B1 | Trending — en çok görüntülenen haberler (view_count'dan) | ⭐⭐⭐⭐ | Düşük | **EVET** |
| B2 | Source preferences — Live'da hangi kaynakların gösterileceğini kullanıcı seçsin | ⭐⭐⭐ | Düşük | **EVET** |
| B3 | Layout density (compact/comfortable) — kart yoğunluğu toggle | ⭐⭐ | Düşük | **EVET** |
| B4 | Onboarding'de favori kategori seçimi | ⭐⭐⭐ | Orta | Sonraki iter |
| B5 | "For You" — okunan kategorilere göre öneri | ⭐⭐⭐ | Yüksek | Sonraki iter |
| B6 | Reading streak — günlük okuma serisi gamification | ⭐⭐ | Orta | Sonraki iter |

### C. Operasyon / ops
| # | Özellik | Etki | Efor | Önerilir? |
|---|---------|------|------|-----------|
| C1 | Diagnostics screen — API durumu, cache boyutu, kaynak sağlığı | ⭐⭐⭐ (dev) | Düşük | **EVET** |
| C2 | Cache temizleme aksiyonu (gerçek) | ⭐⭐ | Düşük | C1 ile birlikte |
| C3 | Health endpoint canlı göstergeli | ⭐⭐ | Düşük | C1 ile birlikte |
| C4 | Local push notifications (WorkManager) | ⭐⭐⭐ | Yüksek | Phase-3 |
| C5 | Background fetch | ⭐⭐ | Yüksek | Phase-3 |
| C6 | Offline mode | ⭐⭐⭐ | Çok yüksek | Phase-3 |

### D. Sosyal / paylaşım
| # | Özellik | Etki | Efor | Önerilir? |
|---|---------|------|------|-----------|
| D1 | Quote card — alıntıyı paylaşılabilir görsele çevir | ⭐⭐ | Orta | Sonraki iter |
| D2 | PDF export | ⭐⭐ | Yüksek | Phase-3 |
| D3 | Yorumlar (UI-only mock) | ⭐ | Orta | Phase-3 |

## 3. Bu iterasyonda kodlanacaklar

Toplam **7 özellik**, en yüksek değer/efor oranı:

1. **A1** — Read/unread göstergesi (ArticleCard, HomeScreen, BookmarksScreen, CategoryArticlesScreen)
2. **A2** — Reading progress restore (yeni `ReadingProgressProvider`, ArticleDetailScreen)
3. **A3** — TL;DR summary card (ArticleDetailScreen üstüne)
4. **A4** — Reading mode toggle + sepia tema (yeni `ReadingThemeProvider`, ArticleDetailScreen)
5. **B1** — Trending section (yeni endpoint `/articles/trending`, HomeScreen)
6. **B2** — Source preferences (yeni `SourcePreferencesScreen`, mevcut `PreferencesProvider` genişletmesi)
7. **B3** — Layout density toggle (Settings'te yeni segmented button, ArticleCard kompakt varyant)
8. **C1** — Diagnostics screen (yeni `DiagnosticsScreen`, mevcut `/external/health` endpoint'ini gösterir)

**Bonus**: Settings yeniden organize, "Veriler" başlığına Trending+SourcePrefs+Diagnostics girişleri.

## 4. Mimari etki

### Yeni provider'lar (3)
- `ReadingProgressProvider` — `Map<articleId, double>` SharedPreferences kalıcı, scroll yüzdesi 0..1
- `ReadingThemeProvider` — `enum {normal, sepia}` + `enum {compact, comfortable}` density
- (`SourcePreferencesProvider` ya da `PreferencesProvider`'a entegre)

### Yeni endpointler (1)
- `GET /articles/trending?limit=N` — view_count DESC, ilk N. ArticleRepository'ye `trending()` metodu eklenir.

### Yeni ekranlar (3)
- `TrendingScreen` (opsiyonel; mevcutsa home section yeterli) — yeni iter
- `SourcePreferencesScreen` (Settings sub-page)
- `DiagnosticsScreen` (Settings sub-page)

### Mevcut ekran güncellemeleri (4)
- `HomeScreen` — Trending bölümü
- `ArticleDetailScreen` — TL;DR card + reading mode toggle + scroll restore
- `ArticleCard` — read/unread badge + density variant
- `SettingsScreen` — yeni navigasyon girişleri + density toggle

## 5. Test stratejisi

1. `flutter analyze` (sıfır sorun hedefi)
2. Backend canlı test — `/articles/trending` yeni endpoint
3. Emülatör akış testi:
   - Bir haberi aç, geri dön → listede "Okundu" + scroll restore çalışıyor mu?
   - Home → Trending bölümü görünür mü?
   - Detail → reading mode toggle sepia tema açıyor mu?
   - Settings → Source preferences alt sayfası, kaydetme kalıcı mı?
   - Settings → Diagnostics sayfası canlı durum gösteriyor mu?
   - Density toggle ArticleCard'lara yansıyor mu?
4. Hata mesajları, runtime exception yokluğu

## 6. Yol haritası — sonraki iterasyonlar

### Phase-3 (orta vade)
- Local notifications (WorkManager + flutter_local_notifications)
- Offline mode (Hive/Drift)
- Onboarding kategori seçimi
- "For You" feed
- Reading streak gamification

### Phase-4 (uzun vade)
- TTS okuma
- Translation
- Quote card (canvas image)
- PDF export
- Yorumlar (BE değişiklik)
- Push notifications (FCM)
