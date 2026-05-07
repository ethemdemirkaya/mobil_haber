<?php

declare(strict_types=1);

namespace MobilHaber\External;

/**
 * curl-tabanlı, timeout ve User-Agent kontrollü minimal HTTP istemcisi.
 */
final class HttpClient
{
    public const DEFAULT_UA =
        'mobil_haber/1.0 (+https://github.com/ethemdemirkaya/mobil_haber)';

    /**
     * @return array{status: int, body: string, latencyMs: int, error: ?string}
     */
    public static function get(
        string $url,
        array $headers = [],
        int $timeoutSec = 8,
        string $userAgent = self::DEFAULT_UA
    ): array {
        $start = microtime(true);
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
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
        if ($headers !== []) {
            $h = [];
            foreach ($headers as $k => $v) $h[] = "$k: $v";
            curl_setopt($ch, CURLOPT_HTTPHEADER, $h);
        }
        $body = curl_exec($ch);
        $errno = curl_errno($ch);
        $err = $errno ? curl_error($ch) : null;
        $status = $errno ? 0 : (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        // PHP 8.0+: curl_close artık no-op. Handle gc ile kapanır.
        unset($ch);
        $latency = (int) round((microtime(true) - $start) * 1000);
        return [
            'status'    => $status,
            'body'      => is_string($body) ? $body : '',
            'latencyMs' => $latency,
            'error'     => $err,
        ];
    }
}
