<?php

declare(strict_types=1);

namespace MobilHaber\External;

/**
 * curl_multi tabanlı paralel HTTP istemcisi.
 * Aggregate gibi N kaynaktan eşzamanlı çekim için kullanılır.
 */
final class ParallelHttpClient
{
    /**
     * @param array<string, array{url: string, headers?: array<string, string>}> $requests
     *        anahtar=request adı, değer=request konfigürasyonu
     * @return array<string, array{status: int, body: string, latencyMs: int, error: ?string}>
     */
    public static function getMany(
        array $requests,
        int $timeoutSec = 12,
        string $userAgent = HttpClient::DEFAULT_UA
    ): array {
        if ($requests === []) return [];

        $multi = curl_multi_init();
        $handles = [];
        $startTimes = [];
        $start = microtime(true);

        foreach ($requests as $name => $cfg) {
            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL            => $cfg['url'],
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_MAXREDIRS      => 4,
                CURLOPT_TIMEOUT        => $timeoutSec,
                CURLOPT_CONNECTTIMEOUT => max(5, min(10, $timeoutSec)),
                CURLOPT_USERAGENT      => $userAgent,
                CURLOPT_SSL_VERIFYPEER => true,
                CURLOPT_SSL_VERIFYHOST => 2,
                CURLOPT_ENCODING       => '',
            ]);
            if (!empty($cfg['headers'])) {
                $h = [];
                foreach ($cfg['headers'] as $k => $v) $h[] = "$k: $v";
                curl_setopt($ch, CURLOPT_HTTPHEADER, $h);
            }
            curl_multi_add_handle($multi, $ch);
            $handles[$name] = $ch;
            $startTimes[$name] = microtime(true);
        }

        // Tüm transferleri tamamlanana kadar çevir.
        do {
            $status = curl_multi_exec($multi, $active);
            if ($active) curl_multi_select($multi, 0.05);
        } while ($active && $status === CURLM_OK);

        $results = [];
        foreach ($handles as $name => $ch) {
            $errno = curl_errno($ch);
            $err = $errno ? curl_error($ch) : null;
            $body = curl_multi_getcontent($ch);
            $code = $errno ? 0 : (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
            curl_multi_remove_handle($multi, $ch);
            $latency = (int) round((microtime(true) - ($startTimes[$name] ?? $start)) * 1000);
            $results[$name] = [
                'status'    => $code,
                'body'      => is_string($body) ? $body : '',
                'latencyMs' => $latency,
                'error'     => $err,
            ];
            unset($ch);
        }
        curl_multi_close($multi);
        return $results;
    }
}
