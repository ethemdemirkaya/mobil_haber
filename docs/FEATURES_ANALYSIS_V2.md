# Gereksinim Analizi v2 — Pivot: "Özetleyici"

> Tarih: 2026-05-07 (sonradan güncellendi)
> Önceki belge: `FEATURES_ANALYSIS.md` (v1 — kendi içerikli haber okuyucusu)
> **Bu belge yeni kapsamı tanımlar.**

---

## 1. Yeni kimlik

`mobil_haber` artık **bir haber sağlayıcısı değil, bir özetleyicidir.** Uygulama:

1. **Kendi içerik üretmez.** Hiçbir manuel kuratasyon, hiçbir editöryal seed.
2. **Dış kaynaklardan çeker.** RSS feedleri (AA, TRT, NTV, Sözcü, BBC Türkçe…) ve açık API'ler (GDELT, Hacker News, opsiyonel anahtarlı NewsData/GNews/WorldNews).
3. **Özetleyerek sunar.** Her haberin **özet alanı** ön plana çıkar. Tam içerik **opsiyonel**, "Orijinali oku" düğmesi orijinal kaynağa yönlendirir.
4. **Çok kaynak, tek görünüm.** Kullanıcı 11+ kaynaktan birleştirilmiş, tarih sıralı feed görür.

### Değer önerisi (3 kelime)
*Hızlı · Birleştirilmiş · Özet.*

---

## 2. Eski → Yeni karşılaştırma

| Konu | v1 (önceki) | v2 (yeni) |
|------|-------------|-----------|
| Ana içerik kaynağı | SQLite seed (30 mock makale) | Dış agregate (RSS + API'ler) |
| Detay ekranı içeriği | `article.content` (tam metin) | `article.summary` (özet, vurgulu) + "Orijinali oku" |
| Mock veri rolü | Birincil | **Yalnızca offline fallback** |
| Bookmark/Reading history kapsamı | Mock makaleler | Dış kaynak makaleleri (id'ler `rss-*`, `gdelt-*`…) |
| Trending bölümü | view_count (mock) | Aggregate'in ilk N'i (en yeni + öne çıkan) |
| TL;DR card | Var | **Tek içerik karesi** (artık ana metin de TL;DR) |
| "İçerik" başlığı | "Para Politikası Kurulu, beklentilerin aksine…" | Yok — özet + "Tam haberi orijinal kaynakta okuyun" |
| Outbound link | Yok | **`url_launcher` ile harici tarayıcı** |
| Tasarım dili | Material 3 default | Modern, daha rafine palet + tipografi |

---

## 3. Bu iterasyonda yapılan fix'ler

### A. Mimari (kritik)
- [x] `Article` modeline `sourceUrl` ve `sourceName` eklendi
- [x] `NewsProvider` artık `ExternalNewsRepository.fetchAggregate()` ile besleniyor; başarısızlıkta mock'a düşüyor
- [x] `MockNewsRepository` sadece offline fallback rolünde (development & no-API senaryosu)
- [x] Backend `/articles` ve `/articles/featured` mock için kalıyor (test/dev), Flutter onlardan beslenmiyor

### B. Detay ekranı (kritik)
- [x] "İçerik" bölümü kaldırıldı; özet ana metin
- [x] "Orijinali oku" butonu (`url_launcher` ile harici tarayıcı)
- [x] Kaynak adı + sourceUrl host bilgisi belirgin
- [x] TL;DR card, ana özet konumuna yükseldi

### C. Bağımlılıklar
- [x] `url_launcher: ^6.3.1` eklendi (harici link açma)

### D. Tasarım refresh
- [x] Renk paleti: brand kırmızısı yumuşatıldı (#E53935 → daha modern), accent altın korundu, primary container yumuşadı
- [x] Article kart: daha fazla iç boşluk, daha yumuşak gölge, daha büyük thumbnail oranı
- [x] Tipografi: title font weight 800 → 700 (daha rafine), letter-spacing -0.4 → -0.3
- [x] Bottom nav: ikon boyutu hafif arttı, label spacing dengelendi
- [x] Empty state'lerde gradient daireler büyütüldü, sparkle yerleşimi güncellendi
- [x] AppBar surface tint kaldırıldı (daha düz, modern görünüm)

### E. UX iyileştirmeleri (yeni)
- [x] Detayda "Bu özet [kaynak adı] tarafından sağlanıyor" mikro-bilgi
- [x] Kart altında "≈ X dk okuma" yerine "≈ X dk özet" (gerçeği yansıtır)
- [x] Aggregate yüklenirken iskelet kartlar değişti — daha net "yükleniyor" sinyal
- [x] Hata durumunda fallback bilgilendirmesi: "Çevrimdışısınız — son cache + örnek veriler gösteriliyor"

---

## 4. Veri akışı (yeni)

```
[RSS feeds + API'ler]
     │
     ▼  parse + normalize
[PHP /external/aggregate]   ← (cache: 10 dk dosya)
     │
     ▼  HTTP
[ExternalNewsRepository.fetchAggregate()]
     │
     ▼
[NewsProvider._all]   ← (mock fallback eğer yukarı başarısız)
     │
     ▼
[HomeScreen, ArticleDetailScreen, BookmarksScreen, …]
```

---

## 5. Test çizelgesi

Her aşama için emülatör görsel doğrulama:

1. ✅ Yeni Article model + url_launcher
2. ✅ NewsProvider aggregate'e bağlı
3. ✅ Home ekranı gerçek RSS başlıklarını gösteriyor
4. ✅ Detay: özet + "Orijinali oku" butonu çalışıyor
5. ✅ Modern palet uygulandı (kırmızı yumuşamış)
6. ✅ Article cards daha rafine
7. ✅ flutter analyze: 0 sorun

---

## 6. Sonraki iterasyonlar (ileri Phase-3)

- **Gerçek AI özetleme** — content > 300 kelime ise OpenAI/Claude ile compact özet
- **In-app browser** — `webview_flutter` ile orijinal sayfayı uygulama içinde aç
- **Çoklu özet uzunluğu** — kısa (1-2 cümle) / orta / uzun seçici
- **Paylaşılabilir özet kartı** — image generator
- **Konu bazlı özetleme** — günün özeti tüm kaynaklardan tek paragrafa
