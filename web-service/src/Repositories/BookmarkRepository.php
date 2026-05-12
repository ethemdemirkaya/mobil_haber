<?php

declare(strict_types=1);

namespace MobilHaber\Repositories;

use MobilHaber\Database;
use PDO;

final class BookmarkRepository
{
    private PDO $pdo;

    public function __construct()
    {
        $this->pdo = Database::connection();
    }

    public function ensureUser(string $deviceId): int
    {
        $stmt = $this->pdo->prepare('SELECT id FROM users WHERE device_id = :d');
        $stmt->execute(['d' => $deviceId]);
        $row = $stmt->fetch();
        if ($row !== false) {
            return (int) $row['id'];
        }
        $insert = $this->pdo->prepare(
            'INSERT INTO users (device_id) VALUES (:d)'
        );
        $insert->execute(['d' => $deviceId]);
        return (int) $this->pdo->lastInsertId();
    }

    /** @return list<array<string, mixed>> */
    public function list(string $deviceId): array
    {
        $userId = $this->ensureUser($deviceId);
        $sql = "
            SELECT a.id, a.title, a.summary, a.content, a.category_id, a.image_url,
                   a.published_at, a.read_minutes, a.is_featured, a.view_count,
                   au.name AS author_name, b.created_at AS bookmarked_at
            FROM bookmarks b
            INNER JOIN articles a ON a.id = b.article_id
            INNER JOIN authors  au ON au.id = a.author_id
            WHERE b.user_id = :u
            ORDER BY b.created_at DESC
        ";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute(['u' => $userId]);

        return array_map(
            static fn(array $row): array => [
                'id'            => $row['id'],
                'title'         => $row['title'],
                'summary'       => $row['summary'],
                'content'       => $row['content'],
                'categoryId'    => $row['category_id'],
                'imageUrl'      => $row['image_url'],
                'author'        => $row['author_name'],
                'publishedAt'   => $row['published_at'],
                'readMinutes'   => (int) $row['read_minutes'],
                'isFeatured'    => (bool) $row['is_featured'],
                'viewCount'     => (int) $row['view_count'],
                'bookmarkedAt'  => $row['bookmarked_at'],
            ],
            $stmt->fetchAll(),
        );
    }

    public function add(string $deviceId, string $articleId): bool
    {
        $userId = $this->ensureUser($deviceId);
        $check = $this->pdo->prepare(
            'SELECT 1 FROM articles WHERE id = :id'
        );
        $check->execute(['id' => $articleId]);
        if ($check->fetch() === false) {
            return false;
        }
        $stmt = $this->pdo->prepare(
            'INSERT OR IGNORE INTO bookmarks (user_id, article_id) VALUES (:u, :a)'
        );
        $stmt->execute(['u' => $userId, 'a' => $articleId]);
        return true;
    }

    public function remove(string $deviceId, string $articleId): void
    {
        $userId = $this->ensureUser($deviceId);
        $stmt = $this->pdo->prepare(
            'DELETE FROM bookmarks WHERE user_id = :u AND article_id = :a'
        );
        $stmt->execute(['u' => $userId, 'a' => $articleId]);
    }

    public function clear(string $deviceId): void
    {
        $userId = $this->ensureUser($deviceId);
        $stmt = $this->pdo->prepare('DELETE FROM bookmarks WHERE user_id = :u');
        $stmt->execute(['u' => $userId]);
    }
}
