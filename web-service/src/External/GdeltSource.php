<?php

declare(strict_types=1);

namespace MobilHaber\External;

use MobilHaber\Cache\FileCache;

/**
 * GDELT 2.0 DOC API — anonim, ücretsiz, sınırsız.
 *
 * Türkçe haberler için sourcelang:tur filtresi kullanılır.
 * Dokümantasyon: https://blog.gdeltproject.org/gdelt-doc-2-0-api-debuts/
 */
final class GdeltSource implements ExternalSourceInterface
{
    private const BASE = 'https://api.gdeltproject.org/api/v2/doc/doc';

    private FileCache $cache;

    public function __construct(?FileCache $cache = null, private readonly int $cacheTtlSeconds = 600)
    {
        $this->cache = $cache ?? new FileCache();
    }

    public function id(): string
    {
        return 'gdelt';
    }

    public function name(): string
    {
        return 'GDELT 2.0';
    }

    public function requiresApiKey(): bool
    {
        return false;
    }

    public function isAvailable(): bool
    {
        return true;
    }

    public function fetch(string $query = '', string $category = '', int $limit = 20): array
    {
        $q = trim($query) === '' ? 'sourcelang:tur' : $query . ' sourcelang:tur';
        $params = http_build_query([
            'query'      => $q,
            'mode'       => 'ArtList',
            'format'     => 'json',
            'maxrecords' => max(1, min(250, $limit)),
            'sort'       => 'datedesc',
        ]);
        $url = self::BASE . '?' . $params;

        $cacheKey = 'gdelt|' . $url;
        $cached = $this->cache->get($cacheKey);
        if (is_array($cached)) return $cached;

        $resp = HttpClient::get($url, timeoutSec: 12);
        if ($resp['status'] !== 200) return [];

        $json = json_decode($resp['body'], true);
        if (!is_array($json) || !isset($json['articles']) || !is_array($json['articles'])) {
            return [];
        }

        $items = [];
        foreach ($json['articles'] as $a) {
            $items[] = $this->normalize($a, $category);
        }
        $items = array_values(array_filter($items));
        $this->cache->set($cacheKey, $items, $this->cacheTtlSeconds);
        return $items;
    }

    public function healthCheck(): array
    {
        $url = self::BASE . '?' . http_build_query([
            'query'      => 'sourcelang:tur',
            'mode'       => 'ArtList',
            'format'     => 'json',
            'maxrecords' => 1,
        ]);
        $resp = HttpClient::get($url, timeoutSec: 10);
        if ($resp['error']) {
            return ['ok' => false, 'message' => $resp['error'], 'latencyMs' => $resp['latencyMs']];
        }
        if ($resp['status'] !== 200) {
            return ['ok' => false, 'message' => 'HTTP ' . $resp['status'], 'latencyMs' => $resp['latencyMs']];
        }
        $json = json_decode($resp['body'], true);
        $count = is_array($json['articles'] ?? null) ? count($json['articles']) : 0;
        return [
            'ok'        => true,
            'message'   => "{$count} öge alındı (test sorgusu)",
            'latencyMs' => $resp['latencyMs'],
        ];
    }

    private function normalize(array $a, string $category): ?array
    {
        $title = trim((string) ($a['title'] ?? ''));
        $url = (string) ($a['url'] ?? '');
        if ($title === '' || $url === '') return null;

        $domain = (string) ($a['domain'] ?? parse_url($url, PHP_URL_HOST) ?? 'gdelt');
        $imageUrl = (string) ($a['socialimage'] ?? '');
        if ($imageUrl === '') {
            $imageUrl = 'https://picsum.photos/seed/gdelt-' . urlencode($domain) . '/1200/800';
        }
        // GDELT seendate "20260507T134500Z"
        $rawDate = (string) ($a['seendate'] ?? '');
        $publishedAt = date('c');
        if (preg_match('/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/', $rawDate, $m)) {
            $ts = mktime((int)$m[4], (int)$m[5], (int)$m[6], (int)$m[2], (int)$m[3], (int)$m[1]);
            $publishedAt = date('c', $ts);
        }

        return [
            'id'           => 'gdelt-' . md5($url),
            'title'        => $title,
            'summary'      => mb_substr($title, 0, 280),
            'content'      => $title,
            'categoryId'   => $category !== '' && $category !== 'all' ? $category : 'dunya',
            'imageUrl'     => $imageUrl,
            'author'       => $domain,
            'publishedAt'  => $publishedAt,
            'readMinutes'  => 2,
            'isFeatured'   => false,
            'source'       => 'gdelt',
            'sourceName'   => "GDELT · {$domain}",
            'sourceUrl'    => $url,
        ];
    }
}
