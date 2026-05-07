<?php

declare(strict_types=1);

namespace MobilHaber\Cache;

/**
 * Basit, dosya tabanlı TTL cache. Dış haber API'lerinin rate limit'ini
 * aşmamak için kullanılır.
 */
final class FileCache
{
    private string $dir;

    public function __construct(?string $dir = null)
    {
        $this->dir = $dir ?? __DIR__ . '/../../storage/cache';
        if (!is_dir($this->dir) && !mkdir($this->dir, 0775, true) && !is_dir($this->dir)) {
            throw new \RuntimeException("Cache dizini oluşturulamadı: {$this->dir}");
        }
    }

    public function get(string $key): mixed
    {
        $path = $this->path($key);
        if (!is_file($path)) return null;
        $raw = @file_get_contents($path);
        if ($raw === false) return null;
        $payload = @unserialize($raw, ['allowed_classes' => false]);
        if (!is_array($payload) || !isset($payload['expires'], $payload['value'])) {
            return null;
        }
        if (time() > (int) $payload['expires']) {
            @unlink($path);
            return null;
        }
        return $payload['value'];
    }

    public function set(string $key, mixed $value, int $ttlSeconds): void
    {
        $path = $this->path($key);
        $payload = [
            'expires' => time() + max(1, $ttlSeconds),
            'value'   => $value,
        ];
        @file_put_contents($path, serialize($payload), LOCK_EX);
    }

    public function delete(string $key): void
    {
        @unlink($this->path($key));
    }

    public function clear(): int
    {
        $count = 0;
        foreach (glob($this->dir . '/*.cache') ?: [] as $f) {
            if (@unlink($f)) $count++;
        }
        return $count;
    }

    private function path(string $key): string
    {
        return $this->dir . '/' . sha1($key) . '.cache';
    }
}
