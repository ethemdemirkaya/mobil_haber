<?php

declare(strict_types=1);

namespace MobilHaber;

final class Response
{
    public static function json(mixed $payload, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Headers: Content-Type, X-Device-Id');
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
        // JSON_INVALID_UTF8_SUBSTITUTE: bozuk UTF-8 byte'ları U+FFFD ile yer
        // değiştirir. JSON_PRETTY_PRINT kapalı: production trafiği için
        // gereksiz boyut/chunk overhead'i.
        $encoded = json_encode(
            $payload,
            JSON_UNESCAPED_UNICODE
                | JSON_UNESCAPED_SLASHES
                | JSON_INVALID_UTF8_SUBSTITUTE
        );
        if ($encoded === false) $encoded = '{}';
        echo $encoded;
    }

    public static function ok(mixed $data, array $meta = []): void
    {
        $body = ['data' => $data];
        if ($meta !== []) {
            $body['meta'] = $meta;
        }
        self::json($body, 200);
    }

    public static function created(mixed $data): void
    {
        self::json(['data' => $data], 201);
    }

    public static function noContent(): void
    {
        http_response_code(204);
        header('Access-Control-Allow-Origin: *');
    }

    public static function error(string $message, int $status = 400, ?string $code = null): void
    {
        $payload = [
            'error' => [
                'message' => $message,
                'status'  => $status,
            ],
        ];
        if ($code !== null) {
            $payload['error']['code'] = $code;
        }
        self::json($payload, $status);
    }

    public static function notFound(string $message = 'Kaynak bulunamadı'): void
    {
        self::error($message, 404, 'not_found');
    }

    public static function badRequest(string $message): void
    {
        self::error($message, 400, 'bad_request');
    }

    public static function preflight(): void
    {
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Headers: Content-Type, X-Device-Id');
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
        header('Access-Control-Max-Age: 86400');
        http_response_code(204);
    }
}
