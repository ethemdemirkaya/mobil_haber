<?php

declare(strict_types=1);

namespace MobilHaber\Controllers;

use MobilHaber\External\ExternalSourceInterface;
use MobilHaber\External\SourceRegistry;
use MobilHaber\Response;

final class ExternalNewsController
{
    public function __construct(private readonly SourceRegistry $registry)
    {
    }

    /**
     * GET /external/sources
     */
    public function sources(): void
    {
        $list = [];
        foreach ($this->registry->all() as $s) {
            $list[] = [
                'id'             => $s->id(),
                'name'           => $s->name(),
                'requiresApiKey' => $s->requiresApiKey(),
                'available'      => $s->isAvailable(),
            ];
        }
        Response::ok($list);
    }

    /**
     * GET /external/health
     * Tüm kaynakların sağlık kontrolü.
     */
    public function health(): void
    {
        $results = [];
        foreach ($this->registry->all() as $s) {
            if (!$s->isAvailable()) {
                $results[] = [
                    'id'        => $s->id(),
                    'name'      => $s->name(),
                    'ok'        => false,
                    'message'   => 'Kullanılabilir değil (anahtar yok mu?)',
                    'latencyMs' => 0,
                ];
                continue;
            }
            $hc = $s->healthCheck();
            $results[] = [
                'id'        => $s->id(),
                'name'      => $s->name(),
                'ok'        => (bool) $hc['ok'],
                'message'   => (string) ($hc['message'] ?? ''),
                'latencyMs' => (int) ($hc['latencyMs'] ?? 0),
            ];
        }
        Response::ok($results);
    }

    /**
     * GET /external/articles?source=<id>&q=&category=&limit=20
     * Tek bir kaynağın haberlerini getir.
     */
    public function articles(): void
    {
        $sourceId = (string) ($_GET['source'] ?? '');
        if ($sourceId === '') {
            Response::badRequest('source parametresi zorunlu');
            return;
        }
        $src = $this->registry->find($sourceId);
        if ($src === null) {
            Response::notFound('Kaynak bulunamadı: ' . $sourceId);
            return;
        }
        if (!$src->isAvailable()) {
            Response::error('Kaynak şu an kullanılamıyor (anahtar yok mu?)', 503, 'source_unavailable');
            return;
        }
        $query    = trim((string) ($_GET['q'] ?? ''));
        $category = trim((string) ($_GET['category'] ?? ''));
        $limit    = $this->intParam('limit', 20, 1, 100);
        $items    = $src->fetch($query, $category, $limit);
        Response::ok($items, [
            'source' => $sourceId,
            'count'  => count($items),
            'query'  => $query,
            'category' => $category,
        ]);
    }

    /**
     * GET /external/aggregate?sources=a,b,c&q=&category=&perSource=8
     * Birden fazla kaynağı birleştir, en yeniden eskiye sırala.
     */
    public function aggregate(): void
    {
        $rawSources = trim((string) ($_GET['sources'] ?? ''));
        $sourceIds = $rawSources === ''
            ? array_map(static fn(ExternalSourceInterface $s) => $s->id(), $this->registry->available())
            : array_values(array_filter(array_map('trim', explode(',', $rawSources))));

        $query    = trim((string) ($_GET['q'] ?? ''));
        $category = trim((string) ($_GET['category'] ?? ''));
        $per      = $this->intParam('perSource', 8, 1, 50);

        $combined = [];
        $stats    = [];
        foreach ($sourceIds as $id) {
            $src = $this->registry->find($id);
            if ($src === null) continue;
            if (!$src->isAvailable()) {
                $stats[$id] = ['count' => 0, 'available' => false];
                continue;
            }
            $items = $src->fetch($query, $category, $per);
            foreach ($items as $a) $combined[] = $a;
            $stats[$id] = ['count' => count($items), 'available' => true];
        }

        usort(
            $combined,
            static fn(array $a, array $b) => strcmp((string) $b['publishedAt'], (string) $a['publishedAt'])
        );

        Response::ok($combined, [
            'count'    => count($combined),
            'sources'  => $stats,
            'query'    => $query,
            'category' => $category,
        ]);
    }

    private function intParam(string $key, int $default, int $min, int $max): int
    {
        if (!isset($_GET[$key])) return $default;
        $v = filter_var($_GET[$key], FILTER_VALIDATE_INT);
        if ($v === false) return $default;
        return max($min, min($max, $v));
    }
}
