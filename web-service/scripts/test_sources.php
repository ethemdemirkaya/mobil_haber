<?php

declare(strict_types=1);

/**
 * Tüm dış kaynakların sağlık kontrolü ve örnek fetch denemesi.
 * CLI'dan: php scripts/test_sources.php
 */

require_once __DIR__ . '/../src/Cache/FileCache.php';
require_once __DIR__ . '/../src/External/HttpClient.php';
require_once __DIR__ . '/../src/External/ExternalSourceInterface.php';

// Auto-load all source classes
foreach (glob(__DIR__ . '/../src/External/*.php') ?: [] as $f) {
    require_once $f;
}

use MobilHaber\External\RssFeedSource;

// Türk haber sitelerinin RSS feed'leri (api-search.md'den)
$rssSources = [
    new RssFeedSource('aa-genel',     'Anadolu Ajansı — Genel',  'https://www.aa.com.tr/tr/rss/default?cat=guncel',     'gundem'),
    new RssFeedSource('trt-haber',    'TRT Haber',                'https://www.trthaber.com/sondakika.rss',              'gundem'),
    new RssFeedSource('ntv-gundem',   'NTV — Gündem',             'https://www.ntv.com.tr/gundem.rss',                   'gundem'),
    new RssFeedSource('sozcu-genel',  'Sözcü',                    'https://www.sozcu.com.tr/feeds-rss-category-sozcu',   'gundem'),
    new RssFeedSource('bbc-turkce',   'BBC Türkçe',               'http://feeds.bbci.co.uk/turkce/rss.xml',              'dunya'),
];

$gdelt = class_exists('MobilHaber\External\GdeltSource') ? new \MobilHaber\External\GdeltSource() : null;
$hn    = class_exists('MobilHaber\External\HackerNewsSource') ? new \MobilHaber\External\HackerNewsSource() : null;
$nd    = class_exists('MobilHaber\External\NewsDataIoSource') ? new \MobilHaber\External\NewsDataIoSource(getenv('NEWSDATA_API_KEY') ?: '') : null;
$gn    = class_exists('MobilHaber\External\GNewsSource')      ? new \MobilHaber\External\GNewsSource(getenv('GNEWS_API_KEY') ?: '') : null;
$wn    = class_exists('MobilHaber\External\WorldNewsApiSource') ? new \MobilHaber\External\WorldNewsApiSource(getenv('WORLDNEWS_API_KEY') ?: '') : null;

$all = array_filter(array_merge($rssSources, [$gdelt, $hn, $nd, $gn, $wn]));

echo "🧪 mobil_haber dış kaynak test paneli\n";
echo "═══════════════════════════════════════════════════════\n\n";

foreach ($all as $src) {
    /** @var MobilHaber\External\ExternalSourceInterface $src */
    $id = $src->id();
    $name = $src->name();
    $needsKey = $src->requiresApiKey();
    $available = $src->isAvailable();

    echo "▶ {$name} ({$id})\n";
    echo "  key gerekir: " . ($needsKey ? 'evet' : 'hayır') . "\n";
    echo "  kullanılabilir: " . ($available ? 'evet' : 'hayır (anahtar yok?)') . "\n";

    if (!$available) {
        echo "  ⏭  atlandı\n\n";
        continue;
    }

    $hc = $src->healthCheck();
    $emoji = $hc['ok'] ? '✅' : '❌';
    echo "  {$emoji} health: " . ($hc['message'] ?? '') . " ({$hc['latencyMs']}ms)\n";

    if ($hc['ok']) {
        $items = $src->fetch('', '', 3);
        echo "  📰 örnek 3 haber:\n";
        foreach ($items as $i => $a) {
            echo "     " . ($i + 1) . ". " . mb_substr($a['title'], 0, 70) . "\n";
            echo "        kategori: {$a['categoryId']} · {$a['readMinutes']}dk · " . substr($a['publishedAt'], 0, 16) . "\n";
        }
        if (empty($items)) echo "     (boş)\n";
    }

    echo "\n";
}

echo "═══════════════════════════════════════════════════════\n";
echo "Test tamamlandı.\n";
