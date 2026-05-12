<?php

declare(strict_types=1);

namespace MobilHaber\External;

use MobilHaber\Cache\FileCache;

/**
 * Genel amaçlı RSS / Atom feed kaynağı.
 *
 * Türk haber siteleri (AA, TRT, NTV, Sözcü, Sabah, Yeni Şafak, BBC Türkçe)
 * için bu sınıftan örnekler oluşturulur. Her kayıt mobil_haber kategori
 * id'sine eşlenir.
 */
final class RssFeedSource implements ExternalSourceInterface
{
    private FileCache $cache;

    public function __construct(
        private readonly string $sourceId,
        private readonly string $sourceName,
        private readonly string $feedUrl,
        private readonly string $defaultCategoryId = 'gundem',
        ?FileCache $cache = null,
        private readonly int $cacheTtlSeconds = 600 // 10 dk
    ) {
        $this->cache = $cache ?? new FileCache();
    }

    public function id(): string
    {
        return 'rss-' . $this->sourceId;
    }

    public function name(): string
    {
        return $this->sourceName;
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
        $cacheKey = $this->id() . '|fetch|' . $this->feedUrl;
        $cached = $this->cache->get($cacheKey);
        if (is_array($cached)) {
            return $this->postFilter($cached, $query, $category, $limit);
        }

        $resp = HttpClient::get($this->feedUrl, ['Accept' => 'application/rss+xml, application/xml;q=0.9, */*;q=0.8']);
        if ($resp['status'] !== 200 || $resp['body'] === '') {
            return [];
        }

        $items = $this->parse($resp['body']);
        $this->cache->set($cacheKey, $items, $this->cacheTtlSeconds);
        return $this->postFilter($items, $query, $category, $limit);
    }

    public function healthCheck(): array
    {
        $resp = HttpClient::get(
            $this->feedUrl,
            ['Accept' => 'application/rss+xml, application/xml;q=0.9, */*;q=0.8'],
            timeoutSec: 5
        );
        if ($resp['error']) {
            return ['ok' => false, 'message' => $resp['error'], 'latencyMs' => $resp['latencyMs']];
        }
        if ($resp['status'] !== 200) {
            return ['ok' => false, 'message' => 'HTTP ' . $resp['status'], 'latencyMs' => $resp['latencyMs']];
        }
        $count = count($this->parse($resp['body']));
        return [
            'ok'        => $count > 0,
            'message'   => $count > 0 ? "{$count} öge alındı" : 'Feed boş veya parse edilemedi',
            'latencyMs' => $resp['latencyMs'],
        ];
    }

    /** @return list<array<string, mixed>> */
    private function parse(string $xml): array
    {
        $prev = libxml_use_internal_errors(true);
        $doc = @simplexml_load_string(
            $xml,
            'SimpleXMLElement',
            LIBXML_NOCDATA | LIBXML_NOERROR | LIBXML_NOWARNING
        );
        libxml_use_internal_errors($prev);
        if ($doc === false) return [];

        // RSS 2.0 (channel/item) veya Atom (feed/entry) destekle.
        $items = [];
        if (isset($doc->channel->item)) {
            foreach ($doc->channel->item as $item) {
                $items[] = $this->fromRssItem($item);
            }
        } elseif (isset($doc->entry)) {
            foreach ($doc->entry as $entry) {
                $items[] = $this->fromAtomEntry($entry);
            }
        }
        return array_values(array_filter($items));
    }

    private function fromRssItem(\SimpleXMLElement $item): ?array
    {
        $title = trim((string) $item->title);
        $link  = trim((string) $item->link);
        $desc  = trim((string) $item->description);
        $pub   = (string) $item->pubDate;
        $guid  = trim((string) $item->guid) ?: $link ?: md5($title . $pub);

        if ($title === '') return null;

        // <enclosure url="..." type="image/..."/>
        $imageUrl = '';
        if (isset($item->enclosure)) {
            $attrs = $item->enclosure->attributes();
            $type = (string) ($attrs['type'] ?? '');
            if (str_starts_with($type, 'image/') || $type === '') {
                $imageUrl = (string) ($attrs['url'] ?? '');
            }
        }
        // media:thumbnail / media:content
        if ($imageUrl === '') {
            $media = $item->children('media', true);
            if (isset($media->thumbnail)) {
                $a = $media->thumbnail->attributes();
                $imageUrl = (string) ($a['url'] ?? '');
            } elseif (isset($media->content)) {
                $a = $media->content->attributes();
                $imageUrl = (string) ($a['url'] ?? '');
            }
        }
        // Description içinden ilk <img>
        if ($imageUrl === '' && $desc !== '') {
            if (preg_match('#<img[^>]+src=["\']([^"\']+)["\']#i', $desc, $m)) {
                $imageUrl = $m[1];
            }
        }
        if ($imageUrl === '') {
            $imageUrl = 'https://picsum.photos/seed/' . urlencode($guid) . '/1200/800';
        }

        $summary = $this->stripHtml($desc);
        $published = $this->parseDate($pub) ?: date('c');
        $words = max(1, $this->wordCount($desc));

        return [
            'id'           => $this->id() . '-' . md5($guid),
            'title'        => $title,
            'summary'      => mb_substr($summary, 0, 280),
            'content'      => $summary !== '' ? $summary : $title,
            'categoryId'   => $this->defaultCategoryId,
            'imageUrl'     => $imageUrl,
            'author'       => trim((string) ($item->children('dc', true)->creator ?? '')) ?: $this->sourceName,
            'publishedAt'  => $published,
            'readMinutes'  => max(1, (int) ceil($words / 220)),
            'isFeatured'   => false,
            'source'       => $this->id(),
            'sourceName'   => $this->sourceName,
            'sourceUrl'    => $link,
        ];
    }

    private function fromAtomEntry(\SimpleXMLElement $entry): ?array
    {
        $title = trim((string) $entry->title);
        if ($title === '') return null;
        $linkHref = '';
        foreach ($entry->link as $link) {
            $a = $link->attributes();
            if ((string) ($a['rel'] ?? 'alternate') === 'alternate') {
                $linkHref = (string) ($a['href'] ?? '');
                break;
            }
        }
        $summary = trim((string) ($entry->summary ?? $entry->content ?? ''));
        $pub     = (string) ($entry->updated ?? $entry->published ?? '');
        $guid    = trim((string) $entry->id) ?: $linkHref ?: md5($title);

        $imageUrl = '';
        if ($summary !== '' && preg_match('#<img[^>]+src=["\']([^"\']+)["\']#i', $summary, $m)) {
            $imageUrl = $m[1];
        }
        if ($imageUrl === '') {
            $imageUrl = 'https://picsum.photos/seed/' . urlencode($guid) . '/1200/800';
        }

        $words = max(1, $this->wordCount($summary));

        return [
            'id'           => $this->id() . '-' . md5($guid),
            'title'        => $title,
            'summary'      => mb_substr($this->stripHtml($summary), 0, 280),
            'content'      => $this->stripHtml($summary) ?: $title,
            'categoryId'   => $this->defaultCategoryId,
            'imageUrl'     => $imageUrl,
            'author'       => trim((string) ($entry->author->name ?? '')) ?: $this->sourceName,
            'publishedAt'  => $this->parseDate($pub) ?: date('c'),
            'readMinutes'  => max(1, (int) ceil($words / 220)),
            'isFeatured'   => false,
            'source'       => $this->id(),
            'sourceName'   => $this->sourceName,
            'sourceUrl'    => $linkHref,
        ];
    }

    private function postFilter(array $items, string $query, string $category, int $limit): array
    {
        $q = trim(mb_strtolower($query));
        $filtered = [];
        foreach ($items as $a) {
            if ($q !== '') {
                $hay = mb_strtolower($a['title'] . ' ' . $a['summary']);
                if (!str_contains($hay, $q)) continue;
            }
            if ($category !== '' && $category !== 'all' && $a['categoryId'] !== $category) {
                continue;
            }
            $filtered[] = $a;
            if (count($filtered) >= $limit) break;
        }
        return $filtered;
    }

    private function wordCount(string $html): int
    {
        $text = $this->stripHtml($html);
        if ($text === '') return 0;
        // Unicode-aware: Türkçe ı, ş, ğ, ç, ö, ü dahil tüm harf+rakam dizilerini
        // kelime olarak say.
        return preg_match_all('/[\p{L}\p{N}]+/u', $text);
    }

    private function stripHtml(string $html): string
    {
        $text = strip_tags($html);
        // JSON-bozucu kontrol karakterlerini temizle (BEL, VT, FF, BOM, vs).
        $text = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $text) ?? $text;
        $text = preg_replace('/\s+/u', ' ', $text) ?? $text;
        $decoded = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        // Bozuk UTF-8 byte'ları (web'den gelen içerikte yaygın) düzelt.
        if (function_exists('mb_convert_encoding')) {
            $clean = @mb_convert_encoding($decoded, 'UTF-8', 'UTF-8');
            if (is_string($clean)) $decoded = $clean;
        }
        return trim($decoded);
    }

    private function parseDate(string $raw): ?string
    {
        $raw = trim($raw);
        if ($raw === '') return null;
        $ts = strtotime($raw);
        return $ts === false ? null : date('c', $ts);
    }
}
