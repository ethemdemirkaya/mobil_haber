# mobil_haber API

Flutter uygulaması için PHP 8.2+ ile yazılmış, framework'süz, hafif bir REST API.
Varsayılan olarak SQLite kullanır; isteğe bağlı MySQL desteği vardır.

## Hızlı başlangıç

```bash
# 1) Veritabanı + örnek veri
php scripts/init_db.php

# 2) Gömülü PHP sunucusunu başlat
php -S 127.0.0.1:8080 -t public
```

Servis ayağa kalktığında sağlık kontrolü:

```bash
curl http://127.0.0.1:8080/health
```

## Yapılandırma

Ortam değişkenleri (örnekler `.env.example` içinde):

| Değişken     | Varsayılan                          | Açıklama                          |
|--------------|-------------------------------------|-----------------------------------|
| `DB_DRIVER`  | `sqlite`                            | `sqlite` veya `mysql`             |
| `DB_PATH`    | `./storage/mobil_haber.sqlite`      | SQLite dosyasının yolu            |
| `DB_HOST`    | `127.0.0.1`                         | MySQL host                        |
| `DB_PORT`    | `3306`                              | MySQL port                        |
| `DB_NAME`    | `mobil_haber`                       | MySQL veritabanı adı              |
| `DB_USER`    | `root`                              | MySQL kullanıcı                   |
| `DB_PASS`    | *(boş)*                             | MySQL şifre                       |

PowerShell'de değişken set etme:
```powershell
$env:DB_DRIVER = 'sqlite'
$env:DB_PATH   = 'D:\Github\mobil_haber\web-service\storage\mobil_haber.sqlite'
```

## Uçlar

> Tüm yanıtlar `{"data": ..., "meta": {...}}` veya hata için `{"error": {...}}`
> biçiminde. CORS açık (`*`).

### Sağlık
- `GET /health` → `{ status, service, time }`

### Kategoriler
- `GET /categories` → tüm kategoriler (sıralı)
- `GET /categories/{id}` → tekil

### Makaleler
- `GET /articles?category=&limit=20&offset=0` → liste; meta'da `total`
- `GET /articles/featured?limit=10` → öne çıkanlar
- `GET /articles/search?q=&category=&limit=20&offset=0` → arama
- `GET /articles/{id}` → tekil (`view_count` artar)
- `GET /articles/{id}/related?limit=4` → aynı kategoriden ilgili haberler

### Yer imleri (Bookmarks)
> Tüm bookmark uçları **`X-Device-Id`** başlığını ister; cihaz başına izole.

- `GET /bookmarks` → kullanıcının kayıtlı haberleri (yeniden eskiye)
- `POST /bookmarks` body: `{"articleId":"a1"}` → ekle
- `DELETE /bookmarks/{id}` → tek kaldır
- `DELETE /bookmarks` → tümünü temizle

## Yanıt örneği

```json
{
  "data": [
    {
      "id": "a1",
      "title": "Merkez Bankası faiz kararını açıkladı, …",
      "summary": "Para Politikası Kurulu …",
      "content": "…",
      "categoryId": "ekonomi",
      "imageUrl": "https://picsum.photos/seed/finance1/1200/800",
      "author": "Ayşe Yıldız",
      "publishedAt": "2026-05-07 18:48:00",
      "readMinutes": 4,
      "isFeatured": true,
      "viewCount": 12
    }
  ],
  "meta": { "total": 30, "limit": 20, "offset": 0 }
}
```

## Klasör yapısı

```
web-service/
├── public/
│   ├── index.php          # Front controller (rotalar)
│   └── .htaccess          # Apache rewrite (gömülü PHP server'a gerek yok)
├── src/
│   ├── Database.php       # PDO bağlantı (SQLite/MySQL)
│   ├── Response.php       # JSON + CORS yardımcıları
│   ├── Router.php         # Yöntem + path eşleyici
│   ├── Repositories/      # Category, Article, Bookmark
│   └── Controllers/       # Category, Article, Bookmark
├── schema/
│   ├── 001_schema.sql     # Tablolar + indexler
│   └── 002_seed.sql       # Örnek 30 makale + 10 yazar
└── scripts/
    └── init_db.php        # Şemayı + seed'i uygula
```

## Notlar

- Üretimde Apache/Nginx ile servis edilirse `public/` dizini doc-root yapılır;
  `.htaccess` içindeki rewrite kuralı kullanılır.
- SQLite varsayılanda WAL modunda çalışır (eşzamanlı okuma için).
- API, Flutter `Article` ve `NewsCategory` modelleriyle bire bir uyumlu
  alan adlarıyla yanıt verir (camelCase: `categoryId`, `imageUrl`,
  `publishedAt`, `readMinutes`, `isFeatured`).
