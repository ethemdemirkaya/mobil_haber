<?php

declare(strict_types=1);

namespace MobilHaber\External;

use MobilHaber\Cache\FileCache;

/**
 * GNews API — Free planda 100 istek/gün, max 10 makale/istek, 12 sa gecikme.
 * Türkçe için lang=tr & country=tr.
 * Dokümantasyon: https://gnews.io/docs/v4
 *
 * NOT: Free plan production'da kullanıma izin vermez (ToS). Demo/test ve
 *      uygulama içi keşif için uygundur.
 */
final class GNewsSource implements ExternalSourceInterface
{
    private const BASE_TOP    = 'https://gnews.io/api/v4/top-headlines';
    private const BASE_SEARCH = 'https://gnews.io/api/v4/search';

    private FileCache $cache;

    public function __construct(
        private readonly string $apiKey,
        ?FileCache $cache = null,
        private readonly int $cacheTtlSeconds = 1800
    ) {
        $this->cache = $cache ?? new FileCache();
    }

    public function id(): string
    {
        return 'gnews';
    }

    public function name(): string
    {
        return 'GNews';
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
            'apikey'  => $this->apiKey,
            'lang'    => 'tr',
            'country' => 'tr',
            'max'     => max(1, min(10, $limit)), // Free plan: max 10
        ];
        if ($query !== '') {
            $params['q'] = $query;
            $base = self::BASE_SEARCH;
        } else {
            $base = self::BASE_TOP;
            if ($category !== '' && $category !== 'all') {
                $params['category'] = $this->mapCategoryToProvider($category);
            }
        }
        $url = $base . '?' . http_build_query($params);
        $cacheKey = 'gnews|' . md5($url);
        $cached = $this->cache->get($cacheKey);
        if (is_array($cached)) return $cached;

        $resp = HttpClient::get($url);
        if ($resp['status'] !== 200) return [];
        $json = json_decode($resp['body'], true);
        if (!is_array($json) || !isset($json['articles']) || !is_array($json['articles'])) {
            return [];
        }
        $items = [];
        foreach ($json['articles'] as $r) {
            $n = $this->normalize($r, $category);
            if ($n) $items[] = $n;
        }
        $this->cache->set($cacheKey, $items, $this->cacheTtlSeconds);
        return $items;
    }

    public function healthCheck(): array
    {
        if (!$this->isAvailable()) {
            return ['ok' => false, 'message' => 'API anahtarı tanımsız (GNEWS_API_KEY)', 'latencyMs' => 0];
        }
        $url = self::BASE_TOP . '?' . http_build_query([
            'apikey'  => $this->apiKey,
            'lang'    => 'tr',
            'country' => 'tr',
            'max'     => 1,
        ]);
        $resp = HttpClient::get($url, timeoutSec: 6);
        if ($resp['error']) {
            return ['ok' => false, 'message' => $resp['error'], 'latencyMs' => $resp['latencyMs']];
        }
        if ($resp['status'] !== 200) {
            return ['ok' => false, 'message' => 'HTTP ' . $resp['status'], 'latencyMs' => $resp['latencyMs']];
        }
        return ['ok' => true, 'message' => 'OK (Türkçe top headlines)', 'latencyMs' => $resp['latencyMs']];
    }

    private function normalize(array $r, string $category): ?array
    {
        $title = trim((string) ($r['title'] ?? ''));
        if ($title === '') return null;
        $url   = (string) ($r['url'] ?? '');
        $img   = (string) ($r['image'] ?? '');
        if ($img === '') {
            $img = 'https://picsum.photos/seed/gnews-' . urlencode($url ?: $title) . '/1200/800';
        }
        $description = trim((string) ($r['description'] ?? ''));
        $content     = trim((string) ($r['content'] ?? '')) ?: $description ?: $title;
        $pub         = (string) ($r['publishedAt'] ?? '');
        $iso = $pub !== '' && ($ts = strtotime($pub)) ? date('c', $ts) : date('c');

        $sourceName = (string) ($r['source']['name'] ?? 'GNews');
        $words = preg_match_all('/[\p{L}\p{N}]+/u', $content);

        return [
            'id'           => 'gnews-' . md5($url . $title),
            'title'        => $title,
            'summary'      => mb_substr($description !== '' ? $description : $content, 0, 280),
            'content'      => $content,
            'categoryId'   => $category !== '' && $category !== 'all' ? $category : 'gundem',
            'imageUrl'     => $img,
            'author'       => $sourceName,
            'publishedAt'  => $iso,
            'readMinutes'  => max(1, (int) ceil(($words ?: 30) / 220)),
            'isFeatured'   => false,
            'source'       => 'gnews',
            'sourceName'   => 'GNews · ' . $sourceName,
            'sourceUrl'    => $url,
        ];
    }

    private function mapCategoryToProvider(string $appCategory): string
    {
        return match ($appCategory) {
            'gundem'    => 'general',
            'spor'      => 'sports',
            'ekonomi'   => 'business',
            'teknoloji' => 'technology',
            'dunya'     => 'world',
            'kultur'    => 'entertainment',
            'saglik'    => 'health',
            'bilim'     => 'science',
            default     => 'general',
        };
    }
}
