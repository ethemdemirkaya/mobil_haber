<?php

declare(strict_types=1);

namespace MobilHaber\External;

use MobilHaber\Cache\FileCache;

/**
 * World News API — $9/ay başlangıç, language=tr, source-country=tr destekli.
 * Free trial sınırlı.
 * Dokümantasyon: https://worldnewsapi.com/docs/
 *
 * Endpoint: /search-news (GET)
 * Auth: api-key header VEYA api-key query param
 */
final class WorldNewsApiSource implements ExternalSourceInterface
{
    private const BASE = 'https://api.worldnewsapi.com/search-news';

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
        return 'worldnews';
    }

    public function name(): string
    {
        return 'World News API';
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
            'language'        => 'tr',
            'source-countries' => 'tr',
            'sort'            => 'publish-time',
            'sort-direction'  => 'desc',
            'number'          => max(1, min(100, $limit)),
        ];
        if ($query !== '') $params['text'] = $query;
        $url = self::BASE . '?' . http_build_query($params);
        $cacheKey = 'worldnews|' . md5($url);
        $cached = $this->cache->get($cacheKey);
        if (is_array($cached)) return $cached;

        $resp = HttpClient::get($url, ['x-api-key' => $this->apiKey]);
        if ($resp['status'] !== 200) return [];
        $json = json_decode($resp['body'], true);
        if (!is_array($json) || !isset($json['news']) || !is_array($json['news'])) {
            return [];
        }
        $items = [];
        foreach ($json['news'] as $r) {
            $n = $this->normalize($r, $category);
            if ($n) $items[] = $n;
        }
        $this->cache->set($cacheKey, $items, $this->cacheTtlSeconds);
        return $items;
    }

    public function healthCheck(): array
    {
        if (!$this->isAvailable()) {
            return ['ok' => false, 'message' => 'API anahtarı tanımsız (WORLDNEWS_API_KEY)', 'latencyMs' => 0];
        }
        $url = self::BASE . '?' . http_build_query([
            'language'        => 'tr',
            'source-countries' => 'tr',
            'number'          => 1,
        ]);
        $resp = HttpClient::get($url, ['x-api-key' => $this->apiKey], timeoutSec: 6);
        if ($resp['error']) {
            return ['ok' => false, 'message' => $resp['error'], 'latencyMs' => $resp['latencyMs']];
        }
        if ($resp['status'] !== 200) {
            return ['ok' => false, 'message' => 'HTTP ' . $resp['status'], 'latencyMs' => $resp['latencyMs']];
        }
        return ['ok' => true, 'message' => 'OK (Türkçe TR kaynakları)', 'latencyMs' => $resp['latencyMs']];
    }

    private function normalize(array $r, string $category): ?array
    {
        $title = trim((string) ($r['title'] ?? ''));
        if ($title === '') return null;
        $url   = (string) ($r['url'] ?? '');
        $img   = (string) ($r['image'] ?? '');
        if ($img === '') {
            $img = 'https://picsum.photos/seed/wn-' . urlencode($url ?: $title) . '/1200/800';
        }
        $summary = trim((string) ($r['summary'] ?? ''));
        $content = trim((string) ($r['text'] ?? '')) ?: $summary ?: $title;
        $pub     = (string) ($r['publish_date'] ?? '');
        $iso = $pub !== '' && ($ts = strtotime($pub)) ? date('c', $ts) : date('c');
        $author = trim((string) ($r['author'] ?? '')) ?: (string) ($r['source_country'] ?? 'World News API');
        $words = preg_match_all('/[\p{L}\p{N}]+/u', $content);

        return [
            'id'           => 'worldnews-' . md5($url . $title),
            'title'        => $title,
            'summary'      => mb_substr($summary !== '' ? $summary : $content, 0, 280),
            'content'      => $content,
            'categoryId'   => $category !== '' && $category !== 'all' ? $category : 'gundem',
            'imageUrl'     => $img,
            'author'       => $author,
            'publishedAt'  => $iso,
            'readMinutes'  => max(1, (int) ceil(($words ?: 30) / 220)),
            'isFeatured'   => false,
            'source'       => 'worldnews',
            'sourceName'   => 'World News API',
            'sourceUrl'    => $url,
        ];
    }
}
