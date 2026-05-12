<?php

declare(strict_types=1);

namespace MobilHaber\External;

/**
 * Dış haber kaynaklarının ortak sözleşmesi.
 *
 * Her sağlayıcı (NewsData.io, GNews, RSS, GDELT, vs.) bu arayüzü uygular.
 * Çıktı her zaman uygulamanın `Article` modeline normalize edilmiş diziler:
 *
 *   [
 *     'id'           => string,    // sağlayıcı içinde benzersiz id (öneki ile)
 *     'title'        => string,
 *     'summary'      => string,
 *     'content'      => string,
 *     'categoryId'   => string,    // mobil_haber kategorisine eşlenmiş
 *     'imageUrl'     => string,
 *     'author'       => string,
 *     'publishedAt'  => string,    // ISO8601
 *     'readMinutes'  => int,
 *     'isFeatured'   => bool,
 *     'source'       => string,    // sağlayıcı id'si (ör. 'newsdata-io')
 *     'sourceName'   => string,    // sağlayıcı insan-okur adı
 *     'sourceUrl'    => string,    // makalenin orijinal URL'i (varsa)
 *   ]
 */
interface ExternalSourceInterface
{
    public function id(): string;

    public function name(): string;

    /** API key gerektirir mi? */
    public function requiresApiKey(): bool;

    /** Şu an kullanılabilir mi? (Anahtar varsa, kaynak ulaşılabilirse) */
    public function isAvailable(): bool;

    /**
     * Haber listesi getir.
     *
     * @param string $query    Arama metni (boş olabilir)
     * @param string $category mobil_haber kategori id'si veya ''
     * @param int    $limit    Maks. dönecek makale sayısı
     *
     * @return list<array<string, mixed>> Article-like normalize diziler
     */
    public function fetch(string $query = '', string $category = '', int $limit = 20): array;

    /**
     * Kaynağın ulaşılabilirliğini test eder.
     *
     * @return array{ok: bool, message: string, latencyMs?: int}
     */
    public function healthCheck(): array;
}
