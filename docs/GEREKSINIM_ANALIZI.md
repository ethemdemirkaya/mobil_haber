# mobil_haber — Gereksinim & Uygunluk Analizi

Tarih: 2026-05-07
Branch: `feat/news-app`

## 1. Hedef

Türkçe içerikli, mobil odaklı bir haber okuyucu. Material 3 tasarım dili, açık/koyu
tema, kategori bazlı keşif, arama, yer imi (kaydet) ve özelleştirilebilir okuma deneyimi.
Backend olarak hafif bir PHP REST API ile beslenir (SQLite/MySQL).

## 2. Gerçeklenmiş kapsam

### 2.1 Flutter istemci
- **Tema**: Material 3, ColorScheme.fromSeed (kırmızı), açık/koyu/sistem; S/M/L
  yazı boyutu — `shared_preferences` ile kalıcı.
- **State**: Provider (Theme, News, Bookmark, Search). Tek sorumluluk, ChangeNotifier.
- **Ekranlar**:
  - **Splash** (animasyonlu, 1.6 sn)
  - **Ana Sayfa** (öne çıkanlar carousel'i + kategori chip'leri + son haberler,
    pull-to-refresh, iskelet yükleme)
  - **Detay** (SliverAppBar hero görsel, yazar avatarı, paylaş/kaydet, ilgili haberler)
  - **Arama** (anlık filtre + kategori chip'leri + son aramalar)
  - **Kaydedilenler** (swipe-to-delete + geri al + tümünü sil)
  - **Ayarlar** (tema, yazı boyutu, geçmiş/kayıt temizleme, hakkında)
- **Widget kütüphanesi**: ArticleCard, FeaturedArticleCard, CategoryChip,
  ShimmerBox + skeletonlar, EmptyState, SectionHeader, ArticleImage
  (cached_network_image).
- **Yerelleştirme**: Türkçe metin + `intl` ile `tr_TR` tarih biçimlendirici.
- **Kalite**: `flutter analyze` 0 sorun; const constructorlar; Hero animasyonlar;
  haptic feedback.

### 2.2 PHP API (`web-service/`)
- **Yığın**: PHP 8.2+, framework'süz, PDO. Varsayılan SQLite (WAL); env üzerinden
  MySQL.
- **Şema**: categories, authors, articles, users (device_id), bookmarks. Tarih,
  kategori ve öne çıkan filtreleri için indexler.
- **Seed**: Flutter mock'larıyla bire bir uyumlu 30 makale, 12 kategori, 10 yazar.
- **Uçlar**:
  - `GET /health`
  - `GET /categories`, `GET /categories/{id}`
  - `GET /articles`, `GET /articles/featured`, `GET /articles/{id}`,
    `GET /articles/{id}/related`, `GET /articles/search`
  - `GET|POST|DELETE /bookmarks`, `DELETE /bookmarks/{id}` (X-Device-Id başlığı ile)
- **Yanıt sözleşmesi**: `{ data, meta? }` veya `{ error: { message, status, code } }`.
- **CORS**: `*`. JSON UTF-8 (Türkçe karakterler korunur).

## 3. Tespit edilen eksikler ve aksiyonlar

| # | Eksik | Etki | Aksiyon |
|---|-------|------|---------|
| 1 | İstemci API'ye bağlı değil (yalnız mock) | API'nin var olması bir anlam ifade etmiyor | **Yapıldı**: Repository pattern + ApiNewsRepository + offline fallback |
| 2 | Ağ hatası kullanıcıya gösterilmiyor | Sessiz başarısızlık | **Yapıldı**: NewsProvider error state + ana sayfada banner |
| 3 | "Tümünü gör" navigasyonu yok | Kategoriye derinlemesine inilemiyor | **Yapıldı**: CategoryArticlesScreen + home action |
| 4 | Bildirim butonu sahte (boş onPressed) | Kullanıcı bekleniyor sanır | **Yapıldı**: bottom sheet — "yakında" mesajı + son haberler kısayolu |
| 5 | Ayarlar > Sürüm sabit | Build versiyon değişimi yansımıyor | **Yapıldı**: AppConstants tek noktadan |
| 6 | ApiConfig (base URL) sabit kodlu olamaz | Geliştirme/üretim arasında geçiş | **Yapıldı**: const + dart-define ile override edilebilir |
| 7 | Bookmark server-side sync yok | Cihaz değişiminde kayıplar olur | **Bilerek dışarıda**: yerel-first kalıcılık yeterli; API uçları hazır, Phase-2 |
| 8 | Push bildirim, deep linking, paylaşım gerçek değil | Demo kapsamı dışında | **Bilerek dışarıda** (yer tutucu UI mevcut) |

## 4. Çözüm mimarisi (eksik #1, #2)

```
NewsProvider ──> NewsRepository (abstract)
                    ├── MockNewsRepository (gömülü liste)
                    └── ApiNewsRepository (HTTP) ── ApiClient ── ApiConfig
```

- `ApiConfig.baseUrl`: `--dart-define=API_BASE_URL=https://...` ile override.
  Boşsa `useApi=false` kabul edilir ve mock kullanılır.
- `ApiNewsRepository` 4 sn timeout; başarısızlıkta exception. Provider yakalar,
  `lastError` doldurur, mevcut listeyi korur.
- Banner: ana sayfada error state varsa kırmızı tonlu satır + "Tekrar dene".

## 5. Sözleşme uyumu (Flutter ↔ PHP)

| Alan         | Flutter `Article` | API JSON                 |
|--------------|-------------------|--------------------------|
| id           | `id` (String)     | `id`                     |
| title        | `title`           | `title`                  |
| summary      | `summary`         | `summary`                |
| content      | `content`         | `content`                |
| categoryId   | `categoryId`     | `categoryId`             |
| imageUrl     | `imageUrl`        | `imageUrl`               |
| author       | `author`          | `author` (join'lenmiş)   |
| publishedAt  | `DateTime`        | ISO string (DateTime.parse) |
| readMinutes  | `readMinutes`     | `readMinutes`            |
| isFeatured   | `isFeatured`      | `isFeatured`             |

## 6. Sonraki adımlar (Phase-2)

- Bookmark server-side sync (cihaz id ile)
- Push bildirim (FCM) + deep link (`mobilhaber://article/{id}`)
- Gerçek paylaşım (`share_plus`)
- Çevrimdışı önbellek (Hive/Drift)
- Yazar profili sayfası
- Yorumlar
- Çoklu dil (en, tr) — şu an yalnızca tr
