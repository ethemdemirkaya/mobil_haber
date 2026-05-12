<?php

declare(strict_types=1);

namespace MobilHaber\Controllers;

use MobilHaber\Repositories\BookmarkRepository;
use MobilHaber\Response;

final class BookmarkController
{
    public function __construct(private readonly BookmarkRepository $repo)
    {
    }

    public function index(): void
    {
        $deviceId = $this->requireDeviceId();
        if ($deviceId === null) return;
        Response::ok($this->repo->list($deviceId));
    }

    public function add(): void
    {
        $deviceId = $this->requireDeviceId();
        if ($deviceId === null) return;

        $body = $this->readJsonBody();
        $articleId = isset($body['articleId']) ? (string) $body['articleId'] : '';
        if ($articleId === '') {
            Response::badRequest('articleId zorunlu alandır');
            return;
        }

        $ok = $this->repo->add($deviceId, $articleId);
        if (!$ok) {
            Response::notFound('Makale bulunamadı: ' . $articleId);
            return;
        }
        Response::created(['articleId' => $articleId]);
    }

    public function remove(string $articleId): void
    {
        $deviceId = $this->requireDeviceId();
        if ($deviceId === null) return;
        $this->repo->remove($deviceId, $articleId);
        Response::noContent();
    }

    public function clear(): void
    {
        $deviceId = $this->requireDeviceId();
        if ($deviceId === null) return;
        $this->repo->clear($deviceId);
        Response::noContent();
    }

    private function requireDeviceId(): ?string
    {
        $headers = function_exists('getallheaders') ? getallheaders() : [];
        $deviceId = $headers['X-Device-Id'] ?? $headers['x-device-id']
            ?? ($_SERVER['HTTP_X_DEVICE_ID'] ?? null);
        if (!is_string($deviceId) || trim($deviceId) === '') {
            Response::error('X-Device-Id başlığı zorunludur', 401, 'missing_device_id');
            return null;
        }
        return trim($deviceId);
    }

    private function readJsonBody(): array
    {
        $raw = file_get_contents('php://input') ?: '';
        if ($raw === '') return [];
        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : [];
    }
}
