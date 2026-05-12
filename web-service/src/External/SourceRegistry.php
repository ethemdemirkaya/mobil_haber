<?php

declare(strict_types=1);

namespace MobilHaber\External;

use MobilHaber\Cache\FileCache;

/**
 * Tüm kullanılabilir dış kaynakların merkezi kaydı.
 *
 * Anahtar gerektirmeyen kaynaklar her zaman dahil edilir.
 * Anahtarlı sağlayıcılar, ilgili env var tanımlıysa eklenir.
 */
final class SourceRegistry
{
    /** @var list<ExternalSourceInterface> */
    private array $sources = [];

    public function __construct(?FileCache $cache = null)
    {
        $cache ??= new FileCache();

        // Türk RSS kaynakları (api-search.md'den doğrulanmış URL'ler)
        $this->sources[] = new RssFeedSource('aa-genel',     'Anadolu Ajansı',    'https://www.aa.com.tr/tr/rss/default?cat=guncel',     'gundem',    $cache);
        $this->sources[] = new RssFeedSource('aa-spor',      'AA — Spor',         'https://www.aa.com.tr/tr/rss/default?cat=spor',       'spor',      $cache);
        $this->sources[] = new RssFeedSource('aa-ekonomi',   'AA — Ekonomi',      'https://www.aa.com.tr/tr/rss/default?cat=ekonomi',    'ekonomi',   $cache);
        $this->sources[] = new RssFeedSource('aa-dunya',     'AA — Dünya',        'https://www.aa.com.tr/tr/rss/default?cat=dunya',      'dunya',     $cache);
        $this->sources[] = new RssFeedSource('trt-haber',    'TRT Haber',         'https://www.trthaber.com/sondakika.rss',              'gundem',    $cache);
        $this->sources[] = new RssFeedSource('ntv-gundem',   'NTV — Gündem',      'https://www.ntv.com.tr/gundem.rss',                   'gundem',    $cache);
        $this->sources[] = new RssFeedSource('sozcu-genel',  'Sözcü',             'https://www.sozcu.com.tr/feeds-rss-category-sozcu',   'gundem',    $cache);
        $this->sources[] = new RssFeedSource('bbc-turkce',   'BBC Türkçe',        'http://feeds.bbci.co.uk/turkce/rss.xml',              'dunya',     $cache);

        // Anahtarsız uluslararası kaynaklar
        $this->sources[] = new GdeltSource($cache);
        $this->sources[] = new HackerNewsSource($cache);

        // Anahtarlı kaynaklar (env'de tanımlıysa)
        $newsdataKey = (string) (getenv('NEWSDATA_API_KEY') ?: '');
        if ($newsdataKey !== '') {
            $this->sources[] = new NewsDataIoSource($newsdataKey, $cache);
        } else {
            // Anahtar yokken bile listede görünsün, "kullanılabilir değil" işaretiyle.
            $this->sources[] = new NewsDataIoSource('', $cache);
        }

        $gnewsKey = (string) (getenv('GNEWS_API_KEY') ?: '');
        $this->sources[] = new GNewsSource($gnewsKey, $cache);

        $worldnewsKey = (string) (getenv('WORLDNEWS_API_KEY') ?: '');
        $this->sources[] = new WorldNewsApiSource($worldnewsKey, $cache);
    }

    /** @return list<ExternalSourceInterface> */
    public function all(): array
    {
        return $this->sources;
    }

    public function find(string $id): ?ExternalSourceInterface
    {
        foreach ($this->sources as $s) {
            if ($s->id() === $id) return $s;
        }
        return null;
    }

    /** @return list<ExternalSourceInterface> */
    public function available(): array
    {
        return array_values(array_filter(
            $this->sources,
            static fn(ExternalSourceInterface $s) => $s->isAvailable()
        ));
    }
}
