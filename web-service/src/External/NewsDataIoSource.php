<?php

declare(strict_types=1);

namespace MobilHaber\External;

use MobilHaber\Cache\FileCache;

/**
 * NewsData.io — Free planda commercial kullanım izinli, language=tr destekli.
 * 200 kredi/gün ≈ 2.000 makale. Anahtar `apikey` query parametresinde.
 * Dokümantasyon: https://newsdata.io/documentation
 */
final class NewsDataIoSource implements ExternalSourceInterface
{
    private const BASE = 'https://newsdata.io/api/1/latest';

    private FileCache $cache;

    public function __construct(
        private readonly string $apiKey,
        ?FileCache $cache = null,
        private readonly int $cacheTtlSeconds = 900
    ) {
        $this->cache = $cache ?? new FileCache();
    }

    public function id(): string
    {
        return 'newsdata-io';
    }

    public function name(): string
    {
        return 'NewsData.io';
    }

    public function requiresApiKey(): bool
    {
        return true;
    }

    public function isAvailable(): bool
    {
        return $this->apiKey !== '';
    }

    public function fetch(string $query = '', string $category = '', int $limit = 20): array
    {
        if (!$this->isAvailable()) return [];
        $params = [
            'apikey'   => $this->apiKey,
            'language' => 'tr',
            'size'     => max(1, min(50, $limit)),
        ];
        if ($query !== '') $params['q'] = $query;
        if ($category !== '' && $category !== 'all') {
            $params['category'] = $this->mapCategoryToProvider($category);
        }
        $url = self::BASE . '?' . http_build_query($params);
        $cacheKey = 'newsdata|' . md5($url);
        $cached = $this->cache->get($cacheKey);
        if (is_array($cached)) return $cached;

        $resp = HttpClient::get($url);
        if ($resp['status'] !== 200) return [];
        $json = json_decode($resp['body'], true);
        if (!is_array($json) || !isset($json['results']) || !is_array($json['results'])) {
            return [];
        }
        $items = [];
        foreach ($json['results'] as $r) {
            $n = $this->normalize($r, $category);
            if ($n) $items[] = $n;
        }
        $this->cache->set($cacheKey, $items, $this->cacheTtlSeconds);
        return $items;
    }

    public function healthCheck(): array
    {
        if (!$this->isAvailable()) {
            return ['ok' => false, 'message' => 'API anahtarı tanımsız (NEWSDATA_API_KEY)', 'latencyMs' => 0];
        }
        $url = self::BASE . '?' . http_build_query([
            'apikey'   => $this->apiKey,
            'language' => 'tr',
            'size'     => 1,
        ]);
        $resp = HttpClient::get($url, timeoutSec: 6);
        if ($resp['error']) {
            return ['ok' => false, 'message' => $resp['error'], 'latencyMs' => $resp['latencyMs']];
        }
        if ($resp['status'] !== 200) {
            $msg = "HTTP {$resp['status']}";
            $j = json_decode($resp['body'], true);
            if (is_array($j) && isset($j['results']['message'])) {
                $msg .= ' — ' . $j['results']['message'];
            }
            return ['ok' => false, 'message' => $msg, 'latencyMs' => $resp['latencyMs']];
        }
        return ['ok' => true, 'message' => 'OK (Türkçe içerik)', 'latencyMs' => $resp['latencyMs']];
    }

    private function normalize(array $r, string $category): ?array
    {
        $title = trim((string) ($r['title'] ?? ''));
        if ($title === '') return null;
        $url = (string) ($r['link'] ?? '');
        $imageUrl = (string) ($r['image_url'] ?? '');
        if ($imageUrl === '') {
            $imageUrl = 'https://picsum.photos/seed/' . urlencode((string) ($r['article_id'] ?? $title)) . '/1200/800';
        }

        $description = trim((string) ($r['description'] ?? ''));
        $content = trim((string) ($r['content'] ?? '')) ?: $description ?: $title;
        $publishedAt = (string) ($r['pubDate'] ?? '');
        $iso = $publishedAt !== '' && ($ts = strtotime($publishedAt))
            ? date('c', $ts)
            : date('c');

        $author = '';
        if (!empty($r['creator']) && is_array($r['creator'])) {
            $author = trim((string) reset($r['creator']));
        }
        if ($author === '') $author = (string) ($r['source_name'] ?? 'NewsData.io');

        $words = preg_match_all('/[\p{L}\p{N}]+/u', $content);
        $readMin = max(1, (int) ceil(($words ?: 30) / 220));

        $providerCat = '';
        if (!empty($r['category']) && is_array($r['category'])) {
            $providerCat = (string) reset($r['category']);
        }
        $cat = $category !== '' && $category !== 'all'
            ? $category
            : $this->mapProviderToCategory($providerCat);

        return [
            'id'           => 'newsdata-' . md5((string) ($r['article_id'] ?? $url . $title)),
            'title'        => $title,
            'summary'      => mb_substr($description !== '' ? $description : $content, 0, 280),
            'content'      => $content,
            'categoryId'   => $cat,
            'imageUrl'     => $imageUrl,
            'author'       => $author,
            'publishedAt'  => $iso,
            'readMinutes'  => $readMin,
            'isFeatured'   => false,
            'source'       => 'newsdata-io',
            'sourceName'   => 'NewsData.io · ' . ($r['source_name'] ?? 'unknown'),
            'sourceUrl'    => $url,
        ];
    }

    private function mapCategoryToProvider(string $appCategory): string
    {
        return match ($appCategory) {
            'gundem'    => 'top',
            'spor'      => 'sports',
            'ekonomi'   => 'business',
            'teknoloji' => 'technology',
            'dunya'     => 'world',
            'kultur'    => 'entertainment',
            'saglik'    => 'health',
            'bilim'     => 'science',
            'egitim'    => 'education',
            'yasam'     => 'lifestyle',
            'sanat'     => 'entertainment',
            'seyahat'   => 'tourism',
            default     => 'top',
        };
    }

    private function mapProviderToCategory(string $providerCat): string
    {
        return match (strtolower($providerCat)) {
            'business'      => 'ekonomi',
            'sports'        => 'spor',
            'technology'    => 'teknoloji',
            'science'       => 'bilim',
            'health'        => 'saglik',
            'world'         => 'dunya',
            'entertainment' => 'kultur',
            'education'     => 'egitim',
            'lifestyle'     => 'yasam',
            'tourism'       => 'seyahat',
            default         => 'gundem',
        };
    }
}
