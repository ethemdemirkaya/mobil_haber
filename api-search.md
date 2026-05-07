# Haber API'leri Araştırma Raporu — `mobil_haber`

> **Hazırlanma tarihi:** Mayıs 2026
> **Hedef:** Türkçe haber içeriği önceliklidir; uluslararası kaynaklar tamamlayıcıdır.
> **Mevcut mimari:** Flutter istemci (`lib/data/repositories/api_news_repository.dart`) + PHP arka uç (`web-service/src/Repositories/ArticleRepository.php`).
> **Doğrulama:** Aşağıdaki tüm bilgiler Mayıs 2026 tarihinde web fetch / web search ile birincil veya birincile yakın kaynaklardan doğrulanmıştır. Doğrulama linki her bölümün sonunda **Kaynak** olarak verilmiştir. Şüpheli/eskimiş olabilecek bilgiler "(doğrulanmadı)" işaretiyle açıkça belirtilmiştir.

---

## 1. Yönetici Özeti ve Tavsiyeler

`mobil_haber` projesinin demo aşamasında olduğu gözetilerek hazırlanan üç tavsiye edilen kombinasyon:

### Tavsiye 1 — "Hızlı başla" (sıfır maliyet, demo kalitesi)
- **Birincil:** **NewsData.io Free** (Türkçe `tr` desteği, 200 kredi/gün ≈ 2.000 makale/gün)
- **Tamamlayıcı RSS:** **Anadolu Ajansı + TRT Haber + NTV + Sözcü** RSS feedleri (PHP tarafında SimplePie ile parse)
- **Uluslararası dolgu:** **GNews API Free** (100 istek/gün) veya **GDELT 2.0** (anonim, sınırsız) — uluslararası başlıklar için
- **Toplam aylık maliyet:** **0 USD**
- **Avantaj:** Demo aşamasındaki proje için fazlasıyla yeterli; commercial ticari kullanım için NewsData.io Free'nin koşulları uygundur.
- **Dezavantaj:** NewsData.io free planda saat-bazlı paylaşılmış kuyruğa girmiş olabilir; production'a geçilirken Basic ($199/ay) gerekebilir.

### Tavsiye 2 — "Saf Türkçe odaklı" (sıfır maliyet, en derin Türkçe kapsam)
- **Birincil:** Türk haber sitelerinin **resmi RSS feedleri** (AA, TRT Haber, NTV, Sözcü, Sabah, Yeni Şafak, T24, Bianet, Diken, CNN Türk, Habertürk)
- **Toplulayıcı:** **rss2json.com Free** veya kendi PHP cron'u (SimplePie + 15 dk cache)
- **Uluslararası:** **BBC Türkçe RSS** + **Hacker News API** (teknoloji)
- **Toplam aylık maliyet:** **0 USD**
- **Avantaj:** En geniş Türkçe kapsam, lisans yükü minimum (RSS feedleri publish-için-sunulmuş kabul edilir, ama yine de kaynak gösterimi şarttır).
- **Dezavantaj:** Yapılandırılmış meta-veri (kategori, yazar) feed kalitesine bağlı.

### Tavsiye 3 — "Ölçeklenebilir hibrit" (production hazır)
- **Birincil ücretli:** **World News API Basic** ($9/ay) — 51 Türk kaynağı, 2.144 günlük TR haberi, `tr` dil parametresi
- **İkincil:** **Mediastack Standard** ($24.99/ay) — Türkçe destekli, ticari kullanım hakları dahil
- **Türkçe RSS dolgu:** AA + TRT + 4 büyük gazete RSS
- **Toplam aylık maliyet:** ≈ **$35/ay**
- **Avantaj:** SLA, real-time, ticari kullanım hakları, geniş kapsam.
- **Dezavantaj:** `mobil_haber` hala demo; bu plana geçiş kullanıcı sayısı artana kadar ertelenmelidir.

---

## 2. Karşılaştırma Tablosu

> Fiyatlar Mayıs 2026 itibariyledir. "TR Kaynak" sayısı sağlayıcının kendi beyanı ya da test sorgu örneklemesidir; doğrulanmamış olanlar `~` işaretiyle gösterilmiştir.

### Kategori A — Uluslararası API'ler

| Sağlayıcı | Free Tier | Ücretli Başlangıç | Türkçe (`lang=tr`) | TR Kaynak | Ticari Kullanım (Free) | Auth |
|---|---|---|---|---|---|---|
| **NewsAPI.org** | 100 istek/gün, 24 saat gecikme, dev-only | $449/ay (Business) | Var (`language=tr`) | ~30+ | **Hayır** (sadece dev/test) | API key (header veya query) |
| **GNews API** | 100 istek/gün, 12 saat gecikme, max 10 makale/istek | €49.99/ay (Essential) | Var (`lang=tr`, `country=tr`) | ~25+ | **Hayır** (non-commercial) | API key (query `apikey`) |
| **NewsData.io** | 200 kredi/gün ≈ 2.000 makale | $199/ay (Basic, 20.000 kredi) | Var (`language=tr`) | ~50+ | **Evet** (free planda bile commercial) | API key (`apikey` query) |
| **Mediastack** | 100 çağrı/ay, gecikmeli, HTTPS yok (free) | $24.99/ay (Standard) | Var (13 dilden biri) | Beyan edilmiş, sayı yok | **Hayır** (Standard+) | API key (`access_key` query) |
| **Currents API** | 1.000 istek/gün | $69/ay (Builder) | Var (Turkish listede) | Doğrulanmadı | Açık değil — kontrol edin | Bearer token (Authorization header) |
| **World News API** | 50 puan/gün, 500 istek/gün | **$9/ay** | **Var** (`tr`) | **51 kaynak, 2.144/gün** | Free planda commercial uygundur ama puan yetmez | API key |
| **Bing News Search** | **EMEKLİ** (11 Ağu 2025'te kapatıldı) | — | — | — | — | — |
| **Google News (resmi yok)** | SerpAPI proxy: 100 arama/ay | SerpAPI: $75/ay | SerpAPI: `gl=tr&hl=tr` | Tüm Türk basını | Var (SerpAPI Production) | API key |
| **The Guardian** | Developer key — 5.000 çağrı/gün, 12 rps | Commercial: tier'a göre | İçerik İngilizce; Türkçe arama mümkün ama sonuç İng | 0 (İngiliz gazetesi) | **Sadece kişisel/araştırma** | API key (query) |
| **NYT Developer** | 4.000-10.000 istek/gün (API'ye göre), 10 istek/dk | Free tier yeterli; commercial için ayrı lisans | İçerik İngilizce | 0 | **Sadece non-commercial** | API key (query `api-key`) |
| **AP Media API** | Yok (developer.ap.org üzerinden başvuru) | Müzakere edilir, B2B fiyatlandırma | Türkçe içerik yok | 0 | Lisansa bağlı | OAuth/API key |
| **Reuters Connect** | Yok, B2B abonelik | Müzakere edilir | Az miktarda Türkçe | Az | Lisansa bağlı | OAuth |
| **Hacker News API** | Sınırsız, anonim | $0 (resmi free) | Yok (İng) | 0 | **Var** | Yok |
| **Spaceflight News** | Sınırsız, anonim (v4) | $0 | Yok (İng) | 0 | **Var** | Yok |
| **NewsCatcher** | Free trial (kredi kartsız) | $29/ay – $10K/ay (kaynaklara göre çelişkili) | Doğrulanmadı | Doğrulanmadı | Plana göre | API key |
| **Webz.io (eski Webhose)** | "Forever free" demo plan | Quote-based | Var | Doğrulanmadı | Plana göre | API key |
| **GDELT 2.0** | Sınırsız, anonim | $0 | **Var** (`sourcelang:tur`) | Yüksek (Türkçeyi makine ile İng'e çevirir) | **Var** (akademik/araştırma odaklı) | Yok |

### Kategori B — Türk Yerel Kaynaklar (Resmi API ya da RSS)

| Kaynak | Resmi API | RSS Feed | Yapı | Lisans / Erişim | Not |
|---|---|---|---|---|---|
| Anadolu Ajansı (AA) | Sadece kurumsal abonelik (AAS) | **Var** (publik, 9 kategori) | RSS 2.0 | RSS feed publik, ticari kullanımda kaynak göstermek şart | TVN abonelik tüm fotoğraf+içerik için |
| TRT Haber | Yok (publik) | **Var** (18+ kategori) | RSS 2.0 | RSS publik | Devlet kuruluşu, geniş kategori |
| Hürriyet | Yok | **Var** | RSS 2.0 | Publik | rss.hurriyet.com.tr |
| Milliyet | Yok | **Var** (tek aggregate feed) | RSS 2.0 | Publik | Site `/rss-servisleri` |
| Sabah | Yok | **Var** (15+ kategori) | RSS 2.0 | Publik | Geniş kategori, video+galeri ayrı |
| Sözcü | Yok | **Var** (34 kategori) | RSS 2.0 | Publik | En zengin kategori listesi |
| NTV | Yok | **Var** (5+ kategori) | RSS 2.0 | Publik | NTV Spor ayrı subdomain |
| CNN Türk | Yok | **Var** (kategori + tüm) | RSS 2.0 | Publik | feed/rss path |
| Habertürk | Yok | **Var** | RSS 2.0 | Publik | /rss path |
| BBC Türkçe | Yok (BBC.com API kapalı) | **Var** | RSS 2.0 | Publik (BBC ToS) | feeds.bbci.co.uk/turkce/rss.xml |
| Bianet | Yok | **Var** | RSS 2.0 | CC-BY-NC-ND 4.0 (siteye göre) | bianet.org/biamag.rss |
| Diken | Yok | **Var** | RSS 2.0 / WordPress | Publik | diken.com.tr/feed/ |
| Cumhuriyet | Yok | **Var** | RSS 2.0 | Publik | cumhuriyet.com.tr/rss/son_dakika.xml |
| Yeni Şafak | Yok | **Var** (7+ kategori) | RSS 2.0 | Publik | rss-feeds query string |
| Türkiye gazetesi | Yok | Doğrulanmadı | — | — | Site rss.turkiyegazetesi.com.tr (doğrulanmadı) |
| Star | Yok | **Var** (tek aggregate) | RSS 2.0 | Publik | star.com.tr/rss/rss.asp |
| T24 | Yok | **Var** (rss-listesi mevcut, ama 403 koruması var) | RSS 2.0 | Publik | t24.com.tr/rss/haberler |
| DHA | **Sadece kurumsal abonelik** (~850-900 TL+KDV/dönem) | Yok (publik feed yayınlamıyor) | — | Abonelik | Yayın türü gazete/internet/haber zorunlu |
| İHA | **Sadece kurumsal abonelik** (abone.iha.com.tr) | Sınırlı (rss.aspx) | RSS | Abonelik | Genel publik feed listesi yok |

---

## 3. Kategori A — Uluslararası API'ler (Detaylı)

### A.1 — NewsAPI.org

- **URL:** https://newsapi.org/ — Docs: https://newsapi.org/docs
- **Auth:** API key (HTTP header `X-Api-Key: <KEY>` ya da query `?apiKey=<KEY>`)
- **Free (Developer):**
  - 100 istek/gün, ekstra istek satın alınamaz
  - 24 saat içerik gecikmesi
  - Maksimum 1 ay geri arama
  - **Sadece development/testing** ortamında kullanılabilir, staging ve production yasak
  - CORS sadece `localhost`
- **Ücretli (Business):** $449/ay (yıllık $358.80/ay) — 250.000 istek/ay, real-time, 5 yıl arşiv
- **Advanced:** $1.749/ay — 2.000.000 istek/ay
- **Enterprise:** Custom
- **Türkçe:** `language=tr` parametresi destekleniyor; `country=tr` ile Türk kaynaklar filtrelenebiliyor (~30+ kaynak)
- **Örnek çağrı:**
  ```bash
  curl "https://newsapi.org/v2/top-headlines?country=tr&apiKey=YOUR_KEY"
  ```
- **Yanıt JSON kritik alanları:** `articles[].source.{id,name}`, `articles[].author`, `articles[].title`, `articles[].description`, `articles[].url`, `articles[].urlToImage`, `articles[].publishedAt`, `articles[].content`
- **Önemli kısıtlar:** Free tier'da production yasak — `mobil_haber` Play Store'a çıktığında Business plan zorunlu olur.
- **Kaynak:** https://newsapi.org/pricing (web fetch ile doğrulandı)

### A.2 — GNews API

- **URL:** https://gnews.io/ — Docs: https://docs.gnews.io
- **Auth:** Query parametresi `apikey=<KEY>`
- **Free:**
  - 100 istek/gün
  - 12 saat gecikme
  - İstek başına max 10 makale
  - **Sadece non-commercial / development**
- **Ücretli:**
  - Essential: €49.99/ay (yıllık €39.99/ay)
  - Business: €99.99/ay
  - Enterprise: €249.99/ay
- **Türkçe:** `lang=tr` ve `country=tr` destekleniyor
- **Örnek çağrı:**
  ```bash
  curl "https://gnews.io/api/v4/top-headlines?lang=tr&country=tr&max=10&apikey=YOUR_KEY"
  ```
- **Yanıt:** `articles[].title`, `description`, `content`, `url`, `image`, `publishedAt`, `source.{name,url}`
- **Kapsam beyanı:** "41 dil, 71 ülke"
- **Kaynak:** https://gnews.io/#pricing (web fetch ile doğrulandı)

### A.3 — NewsData.io ⭐ (Türkçe destekli, free planda commercial)

- **URL:** https://newsdata.io/
- **Auth:** Query `?apikey=<KEY>`
- **Free:**
  - 200 kredi/gün (her kredi = 10 makale ≈ 2.000 makale/gün)
  - **Free planda ticari kullanım izinli** (resmi blog'larında belirtilmiş)
  - Tüm dil ve ülke filtreleri açık
- **Ücretli (aylık):**
  - Basic: 20.000 kredi/ay
  - Professional: 50.000 kredi/ay
  - Corporate: 1.000.000 kredi/ay
- **Türkçe:** `language=tr` ve `country=tr` destekleniyor; "89 dil" beyanı (Türkçe kapsamda)
- **Örnek çağrı:**
  ```bash
  curl "https://newsdata.io/api/1/news?apikey=YOUR_KEY&country=tr&language=tr"
  ```
- **Yanıt JSON:** `results[].title`, `link`, `description`, `content`, `pubDate`, `image_url`, `source_id`, `source_name`, `category[]`, `country[]`, `language`, `creator[]`
- **Avantaj:** `mobil_haber` için **birinci tercih** — free planda commercial, Türkçe doğrudan, kategori meta-verileri zengin.
- **Kaynak:** https://newsdata.io/blog/best-free-news-api/ + https://newsdata.io/blog/pricing-plan-in-newsdata-io/ (web search doğruladı)

### A.4 — Mediastack

- **URL:** https://mediastack.com/
- **Auth:** Query `?access_key=<KEY>`
- **Free:** 100 çağrı/ay, gecikmeli, HTTPS yok (free planda HTTP only — production için kullanılamaz)
- **Ücretli:**
  - Standard: $24.99/ay (yıllık $22.99) — 10.000 çağrı/ay, HTTPS, live data, **commercial use**
  - Professional: $99.99/ay — 50.000 çağrı/ay
  - Business: $249.99/ay — 250.000 çağrı/ay
- **Türkçe:** "13 dil"den biri olarak Türkçe destekleniyor; `languages=tr`, `countries=tr`
- **Örnek çağrı:**
  ```bash
  curl "http://api.mediastack.com/v1/news?access_key=YOUR_KEY&countries=tr&languages=tr"
  ```
- **Yanıt:** `data[].author`, `title`, `description`, `url`, `source`, `image`, `category`, `language`, `country`, `published_at`
- **Önemli kısıt:** Free planda HTTPS yok → mobil uygulamada (App Transport Security / Network Security Config) bloklanır. **Demo testlerde bile sınırlı.**
- **Kaynak:** https://mediastack.com/product (web fetch ile doğrulandı)

### A.5 — Currents API

- **URL:** https://currentsapi.services/
- **Auth:** Header `Authorization: <KEY>` (Bearer prefix yok)
- **Free (Developer):** 1.000 istek/gün, 3 ay arşiv, kısmi içerik
- **Ücretli (aylık):**
  - Builder: $69/ay — 75.000 istek/ay
  - Professional: $150/ay — 300.000 istek/ay
  - Enterprise: $300/ay — 600.000 istek/ay
- **Türkçe:** Resmi dil listesinde **Turkish** mevcut
- **Örnek çağrı:**
  ```bash
  curl -H "Authorization: YOUR_KEY" \
    "https://api.currentsapi.services/v1/latest-news?language=tr&country=TR"
  ```
- **Yanıt:** `news[].id`, `title`, `description`, `url`, `author`, `image`, `language`, `category[]`, `published`
- **Kaynak:** https://currentsapi.services/en/pricing + https://docs.currents.dev (web fetch + search ile doğrulandı)

### A.6 — World News API ⭐ (Türk kapsam doğrulandı)

- **URL:** https://worldnewsapi.com/
- **Auth:** API key (header `x-api-key` veya query `?api-key=`)
- **Free:** 50 puan/gün, 500 istek/gün, kredi kartı yok
- **Ücretli:** **$9/ay**'dan başlıyor (en ucuz!)
- **Türkçe:** `language=tr` (resmi dokümantasyon teyit ediyor)
- **Türkiye kapsamı (ÖNEMLİ — doğrulanmış):**
  - **51 izlenen Türk kaynağı**
  - **Günde 2.144 yeni Türkçe haber**
- **Puan sistemi:** Her sonuç başına ≈ 0.01 puan (bazı endpoint'lerde farklı)
- **Örnek çağrı:**
  ```bash
  curl "https://api.worldnewsapi.com/search-news?source-countries=tr&language=tr&api-key=YOUR_KEY"
  ```
- **Kaynak:** https://worldnewsapi.com/docs/news-sources/turkey-news-api/ + https://worldnewsapi.com/pricing/ (web search teyit etti)

### A.7 — Bing News Search API

- **DURUM: EMEKLİ.** 11 Ağustos 2025 tarihinde Microsoft tarafından tamamen kapatıldı, yeni kayıt alınmıyor.
- **Replasman:** Microsoft "Grounding with Bing Search" hizmetini Azure AI Agents üzerinden öneriyor — fakat bu **ham içerik döndürmez**, yalnızca LLM cevaplarını web ile besler.
- **Tavsiye:** `mobil_haber` için kullanılamaz; alternatifler (NewsData, World News API) tercih edilmeli.
- **Kaynak:** https://learn.microsoft.com/en-us/lifecycle/announcements/bing-search-api-retirement (web search ile doğrulandı)

### A.8 — Google News (resmi yok) → SerpAPI

- **URL:** https://serpapi.com/google-news-api
- **Auth:** API key (query `api_key`)
- **Free:** 100 arama/ay
- **Ücretli:** $75/ay'dan başlar (Developer plan, 5.000 arama)
- **Türkçe:** `gl=tr&hl=tr` ile tüm Türk basını
- **Örnek çağrı:**
  ```bash
  curl "https://serpapi.com/search.json?engine=google_news&q=ekonomi&gl=tr&hl=tr&api_key=YOUR_KEY"
  ```
- **Yanıt:** Google News'in tüm yapılandırılmış kartları (sitelinks, "İlgili haberler", source, snippet, thumbnail, date)
- **Önemli not:** Google News'in **resmi public API'si yoktur**. SerpAPI bir scraper-proxy'dir; Google'ın ToS açısından gri alan ama SerpAPI bu sorumluluğu üstlenir.
- **Kaynak:** https://serpapi.com/pricing (web search ile doğrulandı)

### A.9 — The Guardian Open Platform

- **URL:** https://open-platform.theguardian.com/
- **Auth:** API key (query `api-key=test` ile public test ya da kişisel key)
- **Free (Developer):** 5.000 çağrı/gün, max 12 istek/saniye
- **Ücretli (Commercial):** Tier'a göre, müzakere edilir
- **Türkçe:** Yok — içerik tamamen İngilizce. Türkçe arama sorgusu yapılabilir ama sonuç İngilizce
- **Türk kaynak sayısı:** 0
- **Lisans:** Developer key **kişisel projeler/araştırma için**, ticari uygulama Commercial tier gerektirir
- **Örnek çağrı:**
  ```bash
  curl "https://content.guardianapis.com/search?q=turkey&api-key=YOUR_KEY"
  ```
- **Yanıt:** `response.results[].id`, `webTitle`, `webUrl`, `webPublicationDate`, `sectionName`, `apiUrl`
- **Atribüsyon:** Gösterilen her makalede "Powered by The Guardian" tarzında atıf zorunlu (Commercial sözleşme şart koşuyor)
- **Kaynak:** https://open-platform.theguardian.com/access/ (web fetch engellendi; web search teyit etti)

### A.10 — New York Times Developer APIs

- **URL:** https://developer.nytimes.com/
- **Auth:** API key (query `api-key`)
- **Free:** 4.000-10.000 istek/gün (API'ye göre değişir), 10 istek/dakika hard limit
- **Mevcut API'ler:** Article Search, Top Stories, Most Popular, Books, Movie Reviews, Times Wire, Times Tags, Semantic API, Archive
- **Top Stories:** 1.000 istek/gün
- **Article Search:** 10 istek/dakika, max 4.000/gün; sayfa başı 10 sonuç, max 100 sayfa
- **Türkçe:** Yok — tamamen İngilizce
- **Lisans:** **Sadece non-commercial.** Ticari kullanım için ayrı lisans şart.
- **Örnek çağrı:**
  ```bash
  curl "https://api.nytimes.com/svc/topstories/v2/world.json?api-key=YOUR_KEY"
  ```
- **Yanıt:** `results[].title`, `abstract`, `url`, `byline`, `published_date`, `multimedia[]`
- **Kaynak:** GitHub `nytimes/public_api_specs` + https://developer.nytimes.com/apis (web search ile doğrulandı)

### A.11 — The Associated Press (AP) Media API

- **URL:** https://developer.ap.org/ (kurumsal portal)
- **Auth:** API key (developer support üzerinden alınır)
- **Pricing:** **Yayınlanmamış, müzakere edilir** (B2B). Genelde aylık binlerce USD'den başlar (Quora kullanıcı raporları)
- **Free:** Yok — başvuru ve onay gerekir
- **Türkçe içerik:** AP iç sınırlı miktarda Türkçe çeviri yayınlar; öncelikli dil İngilizce
- **Lisans:** Yayın sözleşmesi şart, makale başına atribüsyon ve kaynak göstermek zorunlu
- **`mobil_haber` için tavsiye:** Demo aşamada **kullanılmaz**. İndie geliştiriciler için fiyat eşiği yüksek.
- **Kaynak:** https://github.com/TheAssociatedPress/APISamples + https://developer.ap.org (web search ile doğrulandı)

### A.12 — Reuters Connect / RDP News API

- **URL:** https://www.reutersconnect.com/ — Developer: https://developers.lseg.com/en/api-catalog/refinitiv-data-platform/news-API
- **Auth:** OAuth 2.0 (kurumsal hesap)
- **Pricing:** **Müzakere edilir, B2B**. Thomson Reuters fiyatlandırması user count + content tier'a göre özel hesaplanır
- **Free:** Yok
- **Türkçe içerik:** Sınırlı, çoğunlukla İngilizce
- **`mobil_haber` için tavsiye:** AP gibi, demo aşamada uygun değil.
- **Kaynak:** https://developers.lseg.com (web search ile doğrulandı)

### A.13 — Hacker News API ⭐ (sınırsız ücretsiz)

- **URL:** https://github.com/HackerNews/API
- **Base:** `https://hacker-news.firebaseio.com/v0/`
- **Auth:** **Yok**
- **Rate limit:** Resmi limit yok (15-30 sn polling tavsiye edilir)
- **Türkçe:** Yok — içerik İngilizce, teknoloji odaklı
- **Lisans:** Açık erişim, ticari kullanım izinli
- **Örnek çağrı:**
  ```bash
  curl "https://hacker-news.firebaseio.com/v0/topstories.json"
  curl "https://hacker-news.firebaseio.com/v0/item/8863.json"
  ```
- **Yanıt:** `id`, `by`, `descendants`, `kids[]`, `score`, `time`, `title`, `type`, `url`
- **`mobil_haber` için kullanım:** "Teknoloji" kategorisinde ek içerik kaynağı olarak çok değerli (özellikle çeviri eklenirse).
- **Kaynak:** https://github.com/HackerNews/API (web search ile doğrulandı)

### A.14 — Spaceflight News API ⭐ (sınırsız ücretsiz)

- **URL:** https://www.spaceflightnewsapi.net/ — v4 docs: https://api.spaceflightnewsapi.net/v4/docs/
- **Auth:** v4'te token gerekiyor (sign-up); v3 token'sız
- **Rate limit:** Açık değil, "free public" beyanı
- **Türkçe:** Yok — sadece İngilizce uzay haberleri
- **Lisans:** Açık, ticari kullanım izinli
- **Örnek çağrı:**
  ```bash
  curl "https://api.spaceflightnewsapi.net/v4/articles/?limit=10"
  ```
- **Yanıt:** `results[].id`, `title`, `url`, `image_url`, `news_site`, `summary`, `published_at`, `updated_at`
- **`mobil_haber` için:** "Bilim" / "Uzay" alt-kategorisi için niş içerik.
- **Kaynak:** https://api.spaceflightnewsapi.net/v4/docs/ (web search ile doğrulandı)

### A.15 — NewsCatcher API

- **URL:** https://www.newscatcherapi.com/
- **Auth:** API key
- **Free:** Free trial — kredi kartı yok
- **Pricing:** Kaynaklar arası **çelişki** (RapidAPI'da $29/ay paketler, ana siteden $10.000/ay enterprise sözleşmeleri)
- **Türkçe:** "77+ dil" beyanı; Türkçe **doğrudan teyit edilmedi** ama olasılıkla destekleniyor
- **`mobil_haber` için tavsiye:** Pricing belirsizliği nedeniyle demo aşamada NewsData.io tercih edilmeli.
- **Kaynak:** https://www.newscatcherapi.com/pricing + RapidAPI (web search; çelişkili veri var)

---

## 4. Kategori B — Türk Haber Kaynakları (RSS / Feed Detay)

Aşağıdaki tüm RSS adresleri ya doğrudan kaynağın resmi RSS sayfasından (web fetch ile teyit edildi) ya da topluluk depolarından alınmıştır. Her birinin **publik olarak yayınlandığı** ve standart RSS okuyucularda çalıştığı varsayılmıştır. Gene de proje öncesinde her feed'i `curl` ile bir kez doğrulayın.

### B.1 — Anadolu Ajansı (AA)

- **Resmi API:** Yok (publik). Tam ajans servisi (TVN — fotoğraf+video+text) abonelik gerektirir.
- **Publik RSS sayfası:** https://www.aa.com.tr/tr/teyithatti/p/rss-linkleri (web fetch ile teyit edildi)
- **RSS feedleri (Teyit Hattı):**
  | Kategori | URL |
  |---|---|
  | Tüm Haberler | `https://www.aa.com.tr/tr/teyithatti/rss/news?cat=0` |
  | Politika | `https://www.aa.com.tr/tr/teyithatti/rss/news?cat=politika` |
  | Ekonomi | `https://www.aa.com.tr/tr/teyithatti/rss/news?cat=ekonomi` |
  | Aktüel | `https://www.aa.com.tr/tr/teyithatti/rss/news?cat=aktuel` |
  | Kültür/Sanat | `https://www.aa.com.tr/tr/teyithatti/rss/news?cat=kultur-sanat` |
  | Bilim Teknoloji | `https://www.aa.com.tr/tr/teyithatti/rss/news?cat=bilim-teknoloji` |
  | Gazze | `https://www.aa.com.tr/tr/teyithatti/rss/news?cat=gazze` |
  | Blog | `https://www.aa.com.tr/tr/teyithatti/rss/news?cat=blog` |
  | Teyit Sözlüğü | `https://www.aa.com.tr/tr/teyithatti/rss/news?cat=teyit-sozlugu` |
  | Video | `https://www.aa.com.tr/tr/teyithatti/rss/video` |
- **Genel haber feedi (eski/topluluk):** `https://www.aa.com.tr/tr/rss/default?cat=guncel`
- **Format:** RSS 2.0 + media:thumbnail
- **Lisans:** RSS publik; tam içerik için AAS abonelik (~aylık ücretli, kurumsal)
- **Yorum:** RSS'de **özet ve link** vardır; tam metin için sayfaya yönlendirme şart. Scraping AA ToS'a aykırı olabilir.

### B.2 — TRT Haber

- **Resmi API:** Yok
- **Publik RSS feedleri (web search ile teyit, https://www.trthaber.com/sitene_ekle.html resmi sayfa):**
  | Kategori | URL |
  |---|---|
  | Manşet | `https://www.trthaber.com/manset_articles.rss` |
  | Son Dakika | `https://www.trthaber.com/sondakika_articles.rss` |
  | Gündem | `https://www.trthaber.com/gundem_articles.rss` |
  | Türkiye | `https://www.trthaber.com/turkiye_articles.rss` |
  | Dünya | `https://www.trthaber.com/dunya_articles.rss` |
  | Ekonomi | `https://www.trthaber.com/ekonomi_articles.rss` |
  | Spor | `https://www.trthaber.com/spor_articles.rss` |
  | Yaşam | `https://www.trthaber.com/yasam_articles.rss` |
  | Sağlık | `https://www.trthaber.com/saglik_articles.rss` |
  | Kültür Sanat | `https://www.trthaber.com/kultur_sanat_articles.rss` |
  | Bilim Teknoloji | `https://www.trthaber.com/bilim_teknoloji_articles.rss` |
  | Eğitim | `https://www.trthaber.com/egitim_articles.rss` |
  | İnfografik | `https://www.trthaber.com/infografik_articles.rss` |
  | Özel Haber | `https://www.trthaber.com/ozel_haber_articles.rss` |
  | Dosya Haber | `https://www.trthaber.com/dosya_haber_articles.rss` |
- **Eski biçim:** `https://www.trthaber.com/sondakika.rss` (hala çalışıyor)
- **Format:** RSS 2.0
- **Lisans:** Devlet kuruluşu, RSS publik. Atribüsyon zorunlu.

### B.3 — DHA (Demirören Haber Ajansı)

- **Resmi API:** Sadece **kurumsal abonelik**. Aboneliğe başvuru için:
  - Telefon: +90 212 449 60 60 / +90 212 449 66 33
  - Form: dha.com.tr abonelik
  - Yayın türü zorunlu (gazete/internet/haber/görüntü)
  - Aylık ücret: ~850-900 TL+KDV (2025 verisi)
- **Publik RSS:** **Bulunamadı** (DHA publik feed yayınlamıyor; sadece abone aboneye sunuyor)
- **`mobil_haber` için tavsiye:** Demo aşamada DHA atlanmalı. Production'da yayıncı kuruluş kapsayan abonelik düşünülebilir.

### B.4 — İHA (İhlas Haber Ajansı)

- **Resmi API:** Kurumsal abonelik (https://abone.iha.com.tr)
- **Publik RSS:** Sınırlı feed `http://www.iha.com.tr/rss.aspx` (sayfa erişilebilir ama feed listesi açık değil — manuel test gerekir)
- **`mobil_haber` için tavsiye:** DHA gibi, demo aşamada atlanabilir.

### B.5 — Hürriyet

- **Resmi API:** Yok
- **RSS feedleri:**
  | Kategori | URL |
  |---|---|
  | Anasayfa | `http://www.hurriyet.com.tr/rss/anasayfa` |
  | Gündem | `http://www.hurriyet.com.tr/rss/gundem` |
  | Ekonomi | `http://www.hurriyet.com.tr/rss/ekonomi` |
  | Spor | `http://www.hurriyet.com.tr/rss/spor` |
  | Dünya | `http://www.hurriyet.com.tr/rss/dunya` |
  | Bigpara (finans) | `https://bigpara.hurriyet.com.tr/rss/` |
- **Not:** `rss.hurriyet.com.tr` alt domain'i de (varsa) tercih edilebilir; `http://` versiyonları HTTPS'e yönlendirilebilir.

### B.6 — Milliyet

- **Resmi API:** Yok
- **RSS:** Modern site sadece **tek aggregate feed** sunuyor:
  - `https://www.milliyet.com.tr/rss/rssNew/sondakika` (XML; Son Dakika içinde dünya/gündem/siyaset karışık)
  - Eski URL yapısı: `http://www.milliyet.com.tr/rss/rssNew/gundemRss.xml`, `ekonomiRss.xml`, `teknolojiRss.xml` (topluluk listesinde geçer; site tarafında deprecated görünüyor)
- **RSS sayfası:** https://www.milliyet.com.tr/rss-servisleri/

### B.7 — Sabah ⭐ (en zengin kategori sunan)

- **Resmi API:** Yok
- **RSS feedleri (sabah.com.tr/rss-bilgi sayfasından, web fetch ile teyit edildi):**
  | Kategori | URL |
  |---|---|
  | Tüm Haberler | `https://www.sabah.com.tr/rss/news.xml` |
  | Gündem | `https://www.sabah.com.tr/rss/gundem.xml` |
  | Ekonomi | `https://www.sabah.com.tr/rss/ekonomi.xml` |
  | Spor | `https://www.sabah.com.tr/rss/spor.xml` |
  | Yaşam | `https://www.sabah.com.tr/rss/yasam.xml` |
  | Dünya | `https://www.sabah.com.tr/rss/dunya.xml` |
  | Teknoloji | `https://www.sabah.com.tr/rss/teknoloji.xml` |
  | Turizm | `https://www.sabah.com.tr/rss/turizm.xml` |
  | Otomobil | `https://www.sabah.com.tr/rss/otomobil.xml` |
  | Sağlık | `https://www.sabah.com.tr/rss/saglik.xml` |
  | Kültür Sanat | `https://www.sabah.com.tr/rss/kultur-sanat.xml` |
  | Son Dakika | `https://www.sabah.com.tr/rss/sondakika.xml` |
  | Galeri (Türkiye) | `https://www.sabah.com.tr/rss/galeri/turkiye.xml` |
  | Galeri (Spor) | `https://www.sabah.com.tr/rss/galeri/spor.xml` |
  | Galeri (Magazin) | `https://www.sabah.com.tr/rss/galeri/magazin.xml` |
  | Video | `https://www.sabah.com.tr/rss/video/video.xml` |
  | Günaydın eki | `https://www.sabah.com.tr/rss/gunaydin.xml` |
  | Cumartesi eki | `https://www.sabah.com.tr/rss/cumartesi.xml` |
  | Pazar eki | `https://www.sabah.com.tr/rss/pazar.xml` |
- **Format:** RSS 2.0 + media tag (görsel için zengin)

### B.8 — Sözcü ⭐ (34 kategori — en fazla)

- **Resmi API:** Yok
- **RSS sayfası:** https://www.sozcu.com.tr/rss-servisleri (web fetch ile teyit, 34 kategori listelendi)
- **Genel feedler:**
  - Haberler: `https://www.sozcu.com.tr/feeds-haberler`
  - Son Dakika: `https://www.sozcu.com.tr/feeds-son-dakika`
- **Kategori bazlı feed pattern:** `https://www.sozcu.com.tr/feeds-rss-category-<slug>`
  Örnekler: `gundem`, `dunya`, `ekonomi`, `spor`, `futbol`, `basketbol`, `yasam`, `saglik`, `magazin`, `kultur-sanat`, `egitim`, `astroloji`, `bilim-teknoloji`, `finans`, `borsa`, `kripto`, `emlak`, `emtia`, `otomotiv`, `sigorta`, `hayat`, `kesfet`, `ilan`, `gunun-icinden`, `voleybol`, `dunyadan-spor`, `diger-sporlar`, `yazar`, `sozcu`, `resmi-ilanlar`, `2024-paris-olimpiyatlari`, `euro-2024`
- **Format:** RSS 2.0
- **Yorum:** Kategori-by-kategori en zengin Türk haber kaynağı; `mobil_haber`'in mevcut kategori modelini birebir karşılıyor.

### B.9 — NTV

- **Resmi API:** Yok
- **RSS feedleri:**
  | Kategori | URL |
  |---|---|
  | Gündem | `https://www.ntv.com.tr/gundem.rss` |
  | Ekonomi | `https://www.ntv.com.tr/ekonomi.rss` |
  | Türkiye | `https://www.ntv.com.tr/turkiye.rss` (pattern, doğrulanmadı) |
  | Dünya | `https://www.ntv.com.tr/dunya.rss` (pattern) |
  | Spor anasayfa | `https://www.ntvspor.net/rss/anasayfa` |
  | Futbol | `https://www.ntvspor.net/rss/kategori/futbol` |
  | Basketbol | `https://www.ntvspor.net/rss/kategori/basketbol` |
  | Motor sporları | `https://www.ntvspor.net/rss/kategori/motor-sporlari` |
- **Pattern:** `https://www.ntv.com.tr/<kategori>.rss` muhtemelen tüm kategorilerde çalışır.

### B.10 — Habertürk

- **Resmi API:** Yok
- **RSS feedleri:**
  - Ana: `https://www.haberturk.com/rss`
  - Ekonomi: `https://www.haberturk.com/rss/ekonomi.xml`
  - Spor: `https://www.haberturk.com/rss/spor.xml`
  - Magazin: `https://www.haberturk.com/rss/magazin.xml`
  - Pattern: `https://www.haberturk.com/rss/<kategori>.xml` — diğer kategoriler için doğrulanmadı

### B.11 — CNN Türk

- **Resmi API:** Yok
- **RSS:**
  - Tüm haberler: `https://www.cnnturk.com/feed/rss/all/news`
  - Türkiye: `https://www.cnnturk.com/feed/rss/turkiye/news`
  - Pattern: `https://www.cnnturk.com/feed/rss/<kategori>/news` — `dunya`, `ekonomi`, `spor`, `teknoloji`, `saglik`, `kultur-sanat` slug'larıyla denenebilir

### B.12 — BBC Türkçe

- **Resmi API:** BBC kapatıldı (eskiden BBC News Labs API)
- **RSS:** `http://feeds.bbci.co.uk/turkce/rss.xml` (uzun yıllardır çalışan resmi feed)
- **Lisans:** BBC kullanım koşulları geçerli (atribüsyon zorunlu, ticari yeniden yayın için izin şart)

### B.13 — Bianet

- **Resmi API:** Yok
- **RSS:** `https://bianet.org/biamag.rss` (ana feed)
- **Lisans:** Bianet, içeriklerini Creative Commons benzeri açık koşullarla yayımlar; ama yine de yayın öncesi http://bianet.org sitesinde geçerli koşullara bakılmalı.

### B.14 — Diken

- **Resmi API:** Yok (WordPress üstüne kurulu)
- **RSS:** `https://www.diken.com.tr/feed/` (WordPress standart feed; tüm site)
- **Kategori bazlı:** WordPress kategori feedleri `/<kategori>/feed/` pattern'ı ile çalışır (örn. `https://www.diken.com.tr/kategori/politika/feed/`)

### B.15 — Cumhuriyet

- **Resmi API:** Yok
- **RSS:** `http://www.cumhuriyet.com.tr/rss/son_dakika.xml` (topluluk listesinde mevcut; modern siteyle güncellik doğrulanmadı)
- **Pattern:** `<kategori>.xml` muhtemelen çalışır

### B.16 — Yeni Şafak

- **Resmi API:** Yok
- **RSS sayfası:** https://www.yenisafak.com/rss-listesi (web fetch ile teyit)
- **RSS feedleri (yeni biçim):**
  | Kategori | URL |
  |---|---|
  | Anasayfa | `https://www.yenisafak.com/rss-feeds?take=60` |
  | Gündem | `https://www.yenisafak.com/rss-feeds?category=gundem` |
  | Dünya | `https://www.yenisafak.com/rss-feeds?category=dunya` |
  | Spor | `https://www.yenisafak.com/rss-feeds?category=spor` |
  | Ekonomi | `https://www.yenisafak.com/rss-feeds?category=ekonomi` |
  | Teknoloji | `https://www.yenisafak.com/rss-feeds?category=teknoloji` |
  | Hayat | `https://www.yenisafak.com/rss-feeds?category=hayat` |
- **RSS feedleri (eski biçim — hala çalışıyor olabilir):** `https://www.yenisafak.com/rss?xml=<kategori>`

### B.17 — Türkiye gazetesi

- **Resmi API:** Yok
- **RSS:** Doğrulanmadı; resmi RSS sayfası bulunamadı (turkiyegazetesi.com.tr üzerinde feed link aktif değil)
- **Tavsiye:** Atlanabilir veya `<feed url> 404` riski göze alınarak manuel keşfedilmeli.

### B.18 — Star

- **Resmi API:** Yok
- **RSS:** `https://www.star.com.tr/rss/rss.asp` (tek aggregate feed)
- **Format:** RSS 2.0 (eski ASP biçimi)

### B.19 — T24

- **Resmi API:** Yok
- **RSS sayfası:** https://t24.com.tr/rss-listesi (403 koruması var; tarayıcıda erişilebiliyor ama bot bloke ediliyor — User-Agent header gerekebilir)
- **RSS feedi:** `https://t24.com.tr/rss/haberler` (genel haberler)
- **Yorum:** PHP tarafında SimplePie kullanırken `cURL` User-Agent'ı gerçekçi tarayıcı stringi olarak ayarlamak gerekebilir.

---

## 5. Kategori C — Toplulayıcılar / RSS Proxy Servisleri

### C.1 — RSS2JSON (rss2json.com)

- **URL:** https://rss2json.com/
- **Free:** Sınırlı kullanım (resmi pricing sayfasında ayrıntı seyrek; 10.000 istek/gün civarında olduğu topluluk forumlarında geçer ama doğrulanmadı)
- **Kullanım:**
  ```
  GET https://api.rss2json.com/v1/api.json?rss_url=<encoded-rss-url>&api_key=<KEY>
  ```
- **Avantaj:** Tek satır kullanım, JSON çıktı doğrudan Flutter `http` ile okunabilir
- **Dezavantaj:** Üçüncü-taraf bağımlılık + hız limiti + free planda HTTPS / SLA yok
- **`mobil_haber` için tavsiye:** PHP tarafı zaten var → kendi PHP'mizde SimplePie ile parse etmek tercih edilmeli (3rd-party'a güvenmemek için).

### C.2 — FeedBurner (Google)

- **URL:** https://feedburner.google.com/
- **Durum:** Google tarafından kapatılma sürecinde (uzun süredir yeni feature yok); 2025+ yeni hesaplar pratik olarak alınamıyor.
- **Tavsiye:** Yeni proje için **kullanılmamalı**.

### C.3 — Inoreader API

- **URL:** https://www.inoreader.com/developers/
- **Auth:** OAuth 2.0
- **Pricing:**
  - Free: $0 (API'den içe-istemci için sadece 50 istek/gün, non-commercial)
  - Pro: $90/yıl ($7.50/ay yıllık) — API erişimi tam, 100.000 istek/ay
  - Custom: Quote-based (publik app yayını için)
- **Rate limits:**
  - Zone 1: 10.000/gün
  - Zone 2: 2.000/gün
- **Avantaj:** Inoreader 1000+ feed'i tek hesaba bağlayıp tag/folder mantığıyla gruplayabiliyorsa, API üstünden tek endpoint'ten her şey alınır.
- **Dezavantaj:** Ücretsiz plan ticari `mobil_haber` için yetmez.

### C.4 — Feedly Cloud API

- **URL:** https://developers.feedly.com/
- **Auth:** OAuth 2.0
- **Free (Developer token):** 50 istek/gün, **non-commercial only**
- **Plan token:** 100.000 istek/ay (Feedly Pro+ aboneliği gerektirir)
- **Commercial:** Threat Intelligence / Market Intelligence planları (kurumsal fiyat, quote)
- **Tavsiye:** Demo için Feedly Pro+ aboneliği gerek; uygun maliyetli değil.

### C.5 — Feedity

- **URL:** https://feedity.com/
- **Özellik:** **HTML sayfaları RSS'e çevirir** — RSS'i olmayan kaynaklar için (örn. Türkiye gazetesi gibi) çok değerli
- **Pricing:** Free trial var; aylık planlar $9-$49 arası
- **Tavsiye:** Sadece RSS'i olmayan ama içerik vermesi şart sayılan bir kaynak için kullanılır.

### C.6 — Superfeedr

- **URL:** https://superfeedr.com/
- **Özellik:** **PubSubHubbub gerçek zamanlı feed push** — pull yerine push modeli
- **Pricing:** $9/ay'dan başlar, premium planlar $49+
- **Avantaj:** Cron job yerine webhook'la içerik güncellemek istersek ideal

---

## 6. Kategori D — Diğer Alternatifler

### D.1 — DBpedia / Wikidata

- **Haber için doğrudan kullanılmıyor.** Wikidata, Wikinews entries için query desteği veriyor (https://query.wikidata.org) ama Wikinews'in kendi içerik üretimi son yıllarda yavaş.
- **`mobil_haber` için:** Tavsiye edilmez; haber kaynağı olarak ham/seyrek.

### D.2 — CrowdTangle (Meta)

- **DURUM: KAPALI.** Meta tarafından **14 Ağustos 2024** tarihinde tamamen kapatıldı.
- **Replasman (Meta Content Library — MCL):** Sadece akademik/non-profit araştırmacılara açık; gazete/medya kuruluşları erişemiyor.
- **Alternatifler:** NewsWhip ($), Socialinsider ($), Sotrender ($) — ama hepsi B2B, demo için uygun değil.
- **Tavsiye:** **Kullanılmaz.**

### D.3 — Common Crawl (CC-NEWS)

- **URL:** https://commoncrawl.org/news-crawl
- **Auth:** Yok (AWS S3 Requester Pays — kullanıcı kendi maliyetini öder)
- **Veri:** 2016'dan beri günlük WARC dosyaları, `s3://commoncrawl/crawl-data/CC-NEWS/yyyy/mm/`
- **Format:** WARC (web archive) — parse için warcio, beautifulsoup gerekir
- **Türkçe:** Doğal olarak Türk siteler crawl ediliyor; filtreleme manuel
- **Tavsiye:** **Real-time gereksinimi olan mobil uygulama için uygun değil** — 1 günlük gecikme + ham WARC işleme yükü. Dataset analizi/AI eğitimi için iyi.

### D.4 — GDELT Project ⭐ (sınırsız ücretsiz, akademik düzey)

- **URL:** https://www.gdeltproject.org/
- **API:** GDELT DOC 2.0 https://api.gdeltproject.org/api/v2/doc/doc
- **Auth:** **Yok**, tamamen anonim
- **Rate limit:** Resmi olarak belirtilmemiş; "fair use" beklenir
- **Türkçe:**
  - **65 dilden gerçek zamanlı makine çevirisi**
  - `sourcelang:tur` filtresi ile Türkçe kaynaklar
  - `sourcecountry:tu` (FIPS Türkiye kodu) ile Türkiye-merkezli haberler
- **Örnek çağrı:**
  ```bash
  curl "https://api.gdeltproject.org/api/v2/doc/doc?query=ekonomi%20sourcelang:tur&mode=ArtList&format=json&maxrecords=50"
  ```
- **Yanıt:** `articles[].url`, `url_mobile`, `title`, `seendate`, `socialimage`, `domain`, `language`, `sourcecountry`
- **Avantaj:** **Tamamen ücretsiz**, hem Türkçe hem küresel kapsam, akademik kalite metaveri (tone, themes, GKG concepts).
- **Dezavantaj:** Tam metin döndürmez; sadece title + URL + meta. Article body için orijinal site fetch'i gerekir.
- **`mobil_haber` için tavsiye:** Demo aşamada **NewsData.io ile birlikte** ikincil kaynak olarak çok uygun.
- **Kaynak:** https://blog.gdeltproject.org/gdelt-doc-2-0-api-debuts/ (web search ile teyit)

### D.5 — Webz.io (eski Webhose.io)

- **URL:** https://webz.io/products/news-api/
- **Free:** "Forever free" demo — sınırlar açık değil
- **Pricing:** Quote-based (kurumsal); yıllık binlerce USD raporları var
- **Türkçe:** Destekleniyor (beyana göre 170+ dil)
- **`mobil_haber` için tavsiye:** Pricing belirsizliği nedeniyle demo aşamada atlanmalı.

---

## 7. Entegrasyon Rehberi (`mobil_haber` projesine özel)

Mevcut mimari (Glob taramasıyla doğrulandı):

```
lib/
  data/
    models/article.dart                 (Article model: id, title, summary, content, categoryId, imageUrl, author, publishedAt, readMinutes, isFeatured)
    repositories/
      news_repository.dart              (interface)
      mock_news_repository.dart
      api_news_repository.dart          (PHP /articles endpoint'inden çekiyor)
  core/network/
    api_client.dart                     (HTTP wrapper)
    api_config.dart                     (base URL)

web-service/
  src/
    Repositories/
      ArticleRepository.php             (PDO ile articles tablosundan okuyor)
      CategoryRepository.php
      BookmarkRepository.php
    Controllers/
      ArticleController.php
    Database.php
    Router.php
  public/index.php
  scripts/init_db.php
```

### 7.1 — Sağlayıcı bazlı PHP repository sınıfları

PHP tarafında **her dış sağlayıcı için ayrı bir Source repository** önerilir; sonuç tek bir `Article` JSON sözleşmesine normalize edilir. Tavsiye edilen dosya yapısı:

```
web-service/src/
  Repositories/
    ArticleRepository.php                  (mevcut — DB)
    External/
      ExternalSourceInterface.php          (yeni — fetch(): Article[])
      NewsDataIoSource.php                 (yeni — A.3 sağlayıcı)
      WorldNewsApiSource.php               (yeni — A.6 sağlayıcı)
      RssFeedSource.php                    (yeni — Türkçe RSS'ler için ortak)
      GdeltSource.php                      (yeni — D.4)
    SourceAggregator.php                   (yeni — tüm dış kaynakları paralel çağırır)
  Cache/
    FileCache.php                          (basit dosya tabanlı cache, 15 dk TTL)
```

Her `External\*Source` sınıfı `ExternalSourceInterface` implementasyonu sunar:

```php
interface ExternalSourceInterface {
    /** @return list<array<string, mixed>> Normalized article JSON */
    public function fetch(string $category, int $limit): array;
}
```

### 7.2 — RSS → JSON dönüşümü (PHP)

**Tavsiye edilen kütüphane: SimplePie** (https://simplepie.org).

- Composer: `composer require simplepie/simplepie`
- `composer require php-mime-mail-parser/php-mime-mail-parser` (alternatif: TextLib for HTML strip)
- Avantaj: AA, TRT, Sözcü, Sabah gibi feedleri kutudan çıkar gibi parse ediyor. Görsel için `media:thumbnail`, `enclosure`, `description`'dan ilk `<img>` çıkarma destekli.

İskelet:

```php
namespace MobilHaber\Repositories\External;

use SimplePie;

final class RssFeedSource implements ExternalSourceInterface
{
    public function __construct(
        private readonly string $feedUrl,
        private readonly string $categoryId,
        private readonly string $sourceName,
        private readonly FileCache $cache,
    ) {}

    public function fetch(string $category, int $limit): array
    {
        $cacheKey = 'rss:' . md5($this->feedUrl);
        if ($cached = $this->cache->get($cacheKey)) return $cached;

        $sp = new SimplePie();
        $sp->set_feed_url($this->feedUrl);
        $sp->set_useragent('mobil_haber/1.0 (+https://example.com)');
        $sp->set_cache_location(__DIR__ . '/../../../var/cache/simplepie');
        $sp->set_cache_duration(900); // 15 dk
        $sp->init();

        $articles = [];
        foreach (array_slice($sp->get_items(), 0, $limit) as $item) {
            $articles[] = [
                'id'           => sha1($item->get_permalink()),
                'title'        => $item->get_title(),
                'summary'      => strip_tags($item->get_description() ?? ''),
                'content'      => strip_tags($item->get_content() ?? ''),
                'categoryId'   => $this->categoryId,
                'imageUrl'     => $this->extractImage($item),
                'author'       => $item->get_author()?->get_name() ?? $this->sourceName,
                'publishedAt'  => date(DATE_ATOM, $item->get_date('U') ?: time()),
                'readMinutes'  => $this->estimateReadMinutes($item->get_content() ?? ''),
                'isFeatured'   => false,
            ];
        }

        $this->cache->set($cacheKey, $articles, 900);
        return $articles;
    }

    private function extractImage(\SimplePie\Item $item): string
    {
        $enc = $item->get_enclosure();
        if ($enc && $enc->get_thumbnail()) return $enc->get_thumbnail();
        if ($enc && $enc->get_link()) return $enc->get_link();
        if (preg_match('/<img[^>]+src="([^"]+)"/i', $item->get_content() ?? '', $m)) {
            return $m[1];
        }
        return '';
    }

    private function estimateReadMinutes(string $html): int
    {
        $words = str_word_count(strip_tags($html));
        return max(1, (int) ceil($words / 200));
    }
}
```

**Alternatif kütüphaneler:**
- `lukasbestle/feedreader` — daha hafif ama media tag desteği zayıf
- `laminas/laminas-feed` — Symfony/Laminas ekosisteminde tercih edilir

### 7.3 — JSON sözleşmesinin Article modeline mapping'i

`mobil_haber`'in mevcut `Article` modeli (lib/data/models/article.dart) zaten şu sözleşmeyi bekliyor (api_news_repository.dart `_decodeArticle`):

```
{
  "id": string,
  "title": string,
  "summary": string,
  "content": string,
  "categoryId": string,    // ör: "all", "ekonomi", "spor"
  "imageUrl": string,
  "author": string,
  "publishedAt": string,   // ISO-8601, "T" yerine boşluk da kabul ediliyor
  "readMinutes": int,
  "isFeatured": bool
}
```

**Her dış sağlayıcının yanıtı bu şemaya normalize edilmelidir.** Mapping kuralları:

| Hedef alan | NewsData.io | World News API | RSS (SimplePie) | GDELT |
|---|---|---|---|---|
| `id` | `article_id` | `id` | `sha1(permalink)` | `sha1(url)` |
| `title` | `title` | `title` | `get_title()` | `title` |
| `summary` | `description` | `summary` | `strip_tags(get_description())` | snippet (yok → URL fetch ile çıkar) |
| `content` | `content` | `text` | `strip_tags(get_content())` | yok (orijinal site) |
| `categoryId` | `category[0]` → projenin kategori slug'ına map | `categories[0]` | sabit (feed → kategori) | tema → kategori map |
| `imageUrl` | `image_url` | `image` | enclosure veya `<img src>` regex | `socialimage` |
| `author` | `creator[0]` | `author` | `get_author()->get_name()` veya source | `domain` |
| `publishedAt` | `pubDate` | `publish_date` | `get_date(DATE_ATOM)` | `seendate` |
| `readMinutes` | content uzunluğu / 200 wpm | text uzunluğu / 200 | content uzunluğu / 200 | URL fetch sonrası hesap |
| `isFeatured` | `false` (manuel) | `false` | `false` | `false` |

### 7.4 — Kategori eşleme tablosu (öneri)

Projenin mevcut `NewsCategory` enum'una uyacak biçimde, dış kaynak kategorilerini şu mapping ile çevirin (web-service tarafında bir helper olarak):

```php
private const CATEGORY_MAP = [
    // NewsData.io & World News API
    'top'           => 'gundem',
    'world'         => 'dunya',
    'business'      => 'ekonomi',
    'sports'        => 'spor',
    'technology'    => 'teknoloji',
    'science'       => 'bilim',
    'health'        => 'saglik',
    'entertainment' => 'magazin',
    'politics'      => 'politika',
    // RSS slug'ları zaten Türkçe olduğu için doğrudan geçer
];
```

### 7.5 — Cache stratejisi (rate limit'i aşmamak için)

Demo NewsData.io free planında **200 kredi/gün** vardır. `mobil_haber`'in cache mimarisi:

| Katman | TTL | Yer | Amaç |
|---|---|---|---|
| **L1 — Flutter (in-memory)** | 5 dk | `Provider` state | Aynı sayfada tekrar çağrı yok |
| **L2 — PHP file cache** | **15 dk** | `web-service/var/cache/` | Aynı endpoint farklı kullanıcılarda paylaşılır |
| **L3 — DB persistance** | 6 saat | `articles_external` (yeni tablo) | Sağlayıcı down olsa da uygulama çalışır |
| **L4 — DB (kalıcı arşiv)** | süresiz | `articles` (mevcut tablo) | "Editöryal" seçilen makaleler |

Önerilen tablo:

```sql
CREATE TABLE articles_external (
  id           VARCHAR(64) PRIMARY KEY,           -- sha1(url)
  source       VARCHAR(50) NOT NULL,              -- 'newsdata', 'rss:aa', 'gdelt'
  category_id  VARCHAR(50) NOT NULL,
  payload_json JSON NOT NULL,                     -- normalize edilmiş Article JSON
  fetched_at   DATETIME NOT NULL,
  expires_at   DATETIME NOT NULL,
  INDEX idx_cat (category_id, fetched_at DESC),
  INDEX idx_exp (expires_at)
);
```

**Cron / scheduled task:** PHP `web-service/scripts/refresh_external.php` — 15 dk'da bir çalışır, expired olanları yeniler. Free plan limitlerini aşmamak için: NewsData.io = 4 saatte bir × 6 kategori = 36 istek/gün ≪ 200.

### 7.6 — API key güvenliği

**Asla istemcide saklanmaz.** Yönetim:

1. **PHP tarafı (sunucuda):** Env var ile (`web-service/.env` → `getenv('NEWSDATA_API_KEY')`). `.env` `.gitignore`'da olmalı (zaten `YAPILACAKLAR.md` ile aynı listede)
2. **Loader:** `vlucas/phpdotenv` (`composer require vlucas/phpdotenv`) — `web-service/public/index.php` başında `Dotenv\Dotenv::createImmutable(...)`
3. **Flutter tarafı:** Sadece kendi PHP API'mizin URL'ini biliyor; dış sağlayıcı key'lerini görmez. PHP arka uç proxy görevi görür.
4. **Üretim (örn. Vercel/Heroku/VPS):** Platform env var arayüzünden tanımla, `.env` dosyasını **deploy etme**.

Örnek `.env.example`:

```
NEWSDATA_API_KEY=
WORLDNEWSAPI_KEY=
GNEWS_API_KEY=
RSS_USER_AGENT=mobil_haber/1.0 (+https://github.com/example/mobil_haber)
CACHE_TTL_SECONDS=900
```

### 7.7 — Yeni endpoint'ler (PHP)

Mevcut `/articles` endpoint'inin yanına **kaynak-bazlı** endpointler eklemek yerine, tek `/articles` endpoint'i `?source=external` parametresiyle dış kaynaklardan da besleyebilir:

```
GET /articles                               → DB (mevcut davranış)
GET /articles?source=external               → Aggregator → tüm dış kaynaklar
GET /articles?source=external&provider=aa   → sadece AA RSS
GET /articles?categoryId=ekonomi&source=external  → ekonomi kategorisi tüm dış
```

Mevcut `ApiNewsRepository.fetchAll()` davranışını bozmadan, opsiyonel bir parametre eklenebilir:

```dart
final raw = await _client.get('/articles', query: {
  'limit': '100',
  if (preferExternal) 'source': 'external',
});
```

---

## 8. Yasal Notlar

> **Uyarı:** Aşağıdaki bölüm bilgilendirme amaçlıdır, hukuki danışmanlık değildir. Production deploy öncesi bir avukat/yasal danışmana başvurun.

### 8.1 — Türk hukuku

- **5187 sayılı Basın Kanunu:** İnternet haber siteleri "süreli yayın" tanımına girer (5651 sayılı kanun ile birlikte). `mobil_haber` toplulayıcı olarak konumlanırsa **kaynak gösterimi**, **içerik bütünlüğüne saygı** ve **cevap-tekzip hakkı** mekanizmaları gerekli olabilir.
- **6112 sayılı RTÜK Kanunu:** İnternet yayıncılığını da kapsar (2019 değişiklikleri); şikayetler RTÜK'e gidebilir.
- **5846 sayılı FSEK (Telif):** Haber metinleri telif kapsamındadır. **"Günlük olaylar" istisnası** (FSEK m.36) sadece haber niteliğindeki bilgi için geçerli; kapsamlı haber metni / fotoğraf yeniden yayını **lisans gerektirir**.

### 8.2 — KVKK ve GDPR

- Uygulama **kullanıcı verisi (bookmark, okuma geçmişi)** topluyor. KVKK m.10 (aydınlatma) ve m.5 (rıza/meşru menfaat) gerekir.
- KVKK Aydınlatma Metni + Çerez Politikası + Açık Rıza akışı (özellikle reklam/analitik SDK eklenirse) zorunlu.
- VERBİS kayıt eşiklerine bakılmalı (yıllık ciro, çalışan sayısı). Demo aşamasında muhtemelen istisnada.
- AB kullanıcıları varsa **GDPR** ek yükümlülükler getirir (DPO, DPA, veri taşınabilirliği).

### 8.3 — Atribüsyon zorunlulukları (sağlayıcı bazlı)

| Sağlayıcı | Atribüsyon | Logo gösterimi | Linkback |
|---|---|---|---|
| NewsAPI | Source name + URL | Hayır | Önerilir |
| GNews | Source name | Hayır | Önerilir |
| NewsData.io | Source name | Hayır | Free planda dahi gerekiyor |
| World News API | Source name + ToS'a göre | Hayır | Önerilir |
| The Guardian | "Powered by The Guardian" | Logo opsiyonel | **Zorunlu** |
| NYT | "Source: The New York Times" | Logo + linkback | **Zorunlu** |
| AP | Sözleşmeye göre | Logo zorunlu | Linkback zorunlu |
| RSS (TR siteleri) | Site adı + linkback | Önerilir | **Zorunlu** (Basın Kanunu) |
| GDELT | "Data: GDELT Project" | Hayır | Önerilir |

### 8.4 — robots.txt ve scraping

- RSS feed'i **publik** olarak yayımlandığında `robots.txt`'in kapsamı dışındadır (RSS dosyaları zaten "/feed", "/rss" path'inde sunulur ve genelde `Allow`).
- Ama **HTML scraping** (RSS'i olmayan kaynaklarda, örn. DHA) yapılırsa `robots.txt`'e **uyulmak zorunludur**. Aksi halde Türk Basın Konseyi şikayeti, IP block ve hukuki süreç riski.
- **Tavsiye:** `mobil_haber`'de **scraping kullanmayın**; sadece resmi RSS feedler ve API'ler.
- User-Agent: Daima belirleyici bir UA kullanın (`mobil_haber/1.0 (+contact@example.com)`); abuse durumunda iletişim için.

### 8.5 — Ticari kullanım özet matrisi

| Sağlayıcı | Demo (free) commercial OK? | Production launch (free) OK? |
|---|---|---|
| NewsAPI | **Hayır** | Hayır (Business şart) |
| GNews | Hayır | Hayır (Essential şart) |
| **NewsData.io** | **Evet** | **Evet** (free planda dahi) |
| Mediastack | Hayır | Hayır (Standard şart) |
| Currents | Belirsiz | Önce kontrol edin |
| World News API | Free puan yetmez ama yasal OK | Basic ($9) önerilir |
| The Guardian | **Hayır (sadece kişisel)** | Commercial lisans şart |
| NYT | **Hayır** | Ayrı lisans şart |
| AP, Reuters | — | Kurumsal abonelik şart |
| HN, Spaceflight | **Evet** | **Evet** |
| GDELT | **Evet** | **Evet** (akademik dostu) |
| Türk RSS feedleri | **Evet** (atribüsyon ile) | Evet (atribüsyon + rıza politikası) |

---

## Ek — Hızlı Referans Komutları

### NewsData.io test (Türkçe haberler)
```bash
curl "https://newsdata.io/api/1/news?apikey=YOUR_KEY&country=tr&language=tr&category=top"
```

### World News API test
```bash
curl "https://api.worldnewsapi.com/search-news?source-countries=tr&language=tr&number=10&api-key=YOUR_KEY"
```

### GDELT test (anonim)
```bash
curl "https://api.gdeltproject.org/api/v2/doc/doc?query=ekonomi%20sourcecountry:tu%20sourcelang:tur&mode=ArtList&format=json&maxrecords=20"
```

### AA RSS test (cURL)
```bash
curl -A "mobil_haber/1.0" "https://www.aa.com.tr/tr/teyithatti/rss/news?cat=0"
```

### Sözcü RSS test
```bash
curl -A "mobil_haber/1.0" "https://www.sozcu.com.tr/feeds-rss-category-gundem"
```

### Hacker News test
```bash
curl "https://hacker-news.firebaseio.com/v0/topstories.json"
```

---

## Doğrulama Kaynakları

Bu rapor için web fetch / web search ile doğrulanan birincil kaynaklar:

- NewsAPI.org pricing — https://newsapi.org/pricing (web fetch, doğrulandı Mayıs 2026)
- GNews API pricing — https://gnews.io/#pricing (web fetch, doğrulandı)
- NewsData.io blog — https://newsdata.io/blog/best-free-news-api/, https://newsdata.io/blog/pricing-plan-in-newsdata-io/ (web search)
- Mediastack product — https://mediastack.com/product (web fetch)
- Currents API pricing — https://currentsapi.services/en/pricing (web fetch)
- World News API — https://worldnewsapi.com/docs/news-sources/turkey-news-api/, https://worldnewsapi.com/pricing/ (web search)
- Bing API retirement — https://learn.microsoft.com/en-us/lifecycle/announcements/bing-search-api-retirement (web search)
- Hacker News API — https://github.com/HackerNews/API (web search)
- Spaceflight News API v4 — https://api.spaceflightnewsapi.net/v4/docs/ (web search)
- GDELT 2.0 — https://blog.gdeltproject.org/gdelt-doc-2-0-api-debuts/ (web search)
- AP Developer — https://developer.ap.org/ (web search; pricing yayınlanmamış)
- Reuters / Refinitiv — https://developers.lseg.com/ (web search; pricing müzakere)
- Inoreader API — https://www.inoreader.com/developers/rate-limiting (web search)
- Feedly API — https://developers.feedly.com/reference/request-limits (web search)
- CrowdTangle kapatılması — Columbia Journalism Review, TechCrunch (web search)
- Common Crawl CC-NEWS — https://commoncrawl.org/news-crawl (web search)
- AA RSS — https://www.aa.com.tr/tr/teyithatti/p/rss-linkleri (web fetch)
- Sabah RSS — https://www.sabah.com.tr/rss-bilgi (web fetch)
- Sözcü RSS — https://www.sozcu.com.tr/rss-servisleri (web fetch)
- Yeni Şafak RSS — https://www.yenisafak.com/rss-listesi (web fetch)
- TRT Haber RSS — https://www.trthaber.com/sitene_ekle.html (web search)
- Milliyet RSS — https://www.milliyet.com.tr/rss-servisleri/ (web fetch — sadece tek aggregate feed)
- Habertürk RSS — https://www.haberturk.com/rss (web fetch — sınırlı detay)
- Turkish News RSS topluluk listesi — https://gist.github.com/e-budur/983d969c0f6cf756bbbb60a2892aa964 (web fetch)
- bakinazik/rss rehberi — https://github.com/bakinazik/rss (web fetch)
- DHA abonelik — https://blogaraci.com/dha-abonelik-ucretleri/ (web search; 2025 verisi)
- T24 RSS sayfası — https://t24.com.tr/rss-listesi (web fetch — 403)
- IHA RSS sayfası — https://www.iha.com.tr/rss (web fetch — feed listesi açık değil)

**Şüpheli/eskimiş olabilecek bilgiler (raporda işaretlendi):**
- Cumhuriyet RSS modern sitedeki güncellik (URL pattern eski).
- Habertürk kategori-bazlı feed pattern'ı (sadece 3 kategori test edildi).
- NTV pattern bazlı kategori URL'leri (yalnızca gündem ve ekonomi teyit edildi).
- Türkiye gazetesi RSS feed URL'i (bulunamadı).
- NewsCatcher API gerçek pricing (kaynaklar arası çelişki).
