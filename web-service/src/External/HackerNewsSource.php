<?php

declare(strict_types=1);

namespace MobilHaber\External;

use MobilHaber\Cache\FileCache;

/**
 * Hacker News API — anonim, ücretsiz, sınırsız.
 * Dokümantasyon: https://github.com/HackerNews/API
 *
 * En çok oy alan teknoloji haberlerini getirir, Türkçe değil — uluslararası
 * teknoloji içerik için tamamlayıcı kaynak.
 */
final class HackerNewsSource implements ExternalSourceInterface
{
    private const BASE = 'https://hacker-news.firebaseio.com/v0';

    private FileCache $cache;

    public function __construct(?FileCache $cache = null, private readonly int $cacheTtlSeconds = 300)
    {
        $this->cache = $cache ?? new FileCache();
    }

    public function id(): string
    {
        return 'hackernews';
    }

    public function name(): string
    {
        return 'Hacker News';
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
        $cacheKey = 'hn|topstories|' . $limit;
        $cached = $this->cache->get($cacheKey);
        if (is_array($cached)) {
            return $this->postFilter($cached, $query);
        }

        $resp = HttpClient::get(self::BASE . '/topstories.json');
        if ($resp['status'] !== 200) return [];
        $ids = json_decode($resp['body'], true);
        if (!is_array($ids)) return [];

        $items = [];
        $taken = 0;
        foreach ($ids as $id) {
            if ($taken >= $limit) break;
            $itemResp = HttpClient::get(self::BASE . "/item/{$id}.json");
            if ($itemResp['status'] !== 200) continue;
            $item = json_decode($itemResp['body'], true);
            if (!is_array($item)) continue;
            $normalized = $this->normalize($item);
            if ($normalized === null) continue;
            $items[] = $normalized;
            $taken++;
        }

        $this->cache->set($cacheKey, $items, $this->cacheTtlSeconds);
        return $this->postFilter($items, $query);
    }

    public function healthCheck(): array
    {
        $resp = HttpClient::get(self::BASE . '/topstories.json', timeoutSec: 5);
        if ($resp['error']) {
            return ['ok' => false, 'message' => $resp['error'], 'latencyMs' => $resp['latencyMs']];
        }
        if ($resp['status'] !== 200) {
            return ['ok' => false, 'message' => 'HTTP ' . $resp['status'], 'latencyMs' => $resp['latencyMs']];
        }
        $ids = json_decode($resp['body'], true);
        $n = is_array($ids) ? count($ids) : 0;
        return ['ok' => $n > 0, 'message' => "{$n} top story id'si alındı", 'latencyMs' => $resp['latencyMs']];
    }

    private function normalize(array $item): ?array
    {
        $title = trim((string) ($item['title'] ?? ''));
        if ($title === '') return null;
        $type = (string) ($item['type'] ?? '');
        if ($type !== 'story') return null;
        $url = (string) ($item['url'] ?? '');
        $hnUrl = "https://news.ycombinator.com/item?id=" . (int) ($item['id'] ?? 0);
        $finalUrl = $url !== '' ? $url : $hnUrl;
        $domain = parse_url($finalUrl, PHP_URL_HOST) ?: 'news.ycombinator.com';

        $publishedAt = isset($item['time']) ? date('c', (int) $item['time']) : date('c');

        return [
            'id'           => 'hn-' . (int) $item['id'],
            'title'        => $title,
            'summary'      => $title,
            'content'      => $title,
            'categoryId'   => 'teknoloji',
            'imageUrl'     => 'https://picsum.photos/seed/hn-' . $item['id'] . '/1200/800',
            'author'       => (string) ($item['by'] ?? 'hacker-news'),
            'publishedAt'  => $publishedAt,
            'readMinutes'  => 2,
            'isFeatured'   => false,
            'source'       => 'hackernews',
            'sourceName'   => "Hacker News · {$domain}",
            'sourceUrl'    => $finalUrl,
        ];
    }

    private function postFilter(array $items, string $query): array
    {
        $q = trim(mb_strtolower($query));
        if ($q === '') return $items;
        return array_values(array_filter(
            $items,
            static fn(array $a) => str_contains(mb_strtolower($a['title']), $q)
        ));
    }
}
