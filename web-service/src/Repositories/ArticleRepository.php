<?php

declare(strict_types=1);

namespace MobilHaber\Repositories;

use MobilHaber\Database;
use PDO;

final class ArticleRepository
{
    private PDO $pdo;

    public function __construct()
    {
        $this->pdo = Database::connection();
    }

    /**
     * @return array{items: list<array<string, mixed>>, total: int}
     */
    public function list(?string $categoryId, int $limit, int $offset): array
    {
        $where = '';
        $bindings = [];
        if ($categoryId !== null && $categoryId !== '' && $categoryId !== 'all') {
            $where = 'WHERE a.category_id = :category';
            $bindings['category'] = $categoryId;
        }

        $countSql = "SELECT COUNT(*) AS c FROM articles a $where";
        $countStmt = $this->pdo->prepare($countSql);
        $countStmt->execute($bindings);
        $total = (int) ($countStmt->fetch()['c'] ?? 0);

        $sql = "
            SELECT a.id, a.title, a.summary, a.content, a.category_id, a.image_url,
                   a.published_at, a.read_minutes, a.is_featured, a.view_count,
                   au.name AS author_name
            FROM articles a
            INNER JOIN authors au ON au.id = a.author_id
            $where
            ORDER BY a.published_at DESC
            LIMIT :limit OFFSET :offset
        ";

        $stmt = $this->pdo->prepare($sql);
        foreach ($bindings as $key => $value) {
            $stmt->bindValue($key, $value);
        }
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        return [
            'items' => array_map($this->hydrate(...), $stmt->fetchAll()),
            'total' => $total,
        ];
    }

    /** @return list<array<string, mixed>> */
    public function trending(int $limit = 10): array
    {
        $sql = "
            SELECT a.id, a.title, a.summary, a.content, a.category_id, a.image_url,
                   a.published_at, a.read_minutes, a.is_featured, a.view_count,
                   au.name AS author_name
            FROM articles a
            INNER JOIN authors au ON au.id = a.author_id
            WHERE a.view_count > 0
            ORDER BY a.view_count DESC, a.published_at DESC
            LIMIT :limit
        ";
        $stmt = $this->pdo->prepare($sql);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();
        // Henüz hiçbir makalenin görüntülenmemiş olabilir; bu durumda en yeni
        // featured veya en yenileri döndür (boş liste yerine).
        if (empty($rows)) {
            $stmt = $this->pdo->prepare("
                SELECT a.id, a.title, a.summary, a.content, a.category_id, a.image_url,
                       a.published_at, a.read_minutes, a.is_featured, a.view_count,
                       au.name AS author_name
                FROM articles a
                INNER JOIN authors au ON au.id = a.author_id
                ORDER BY a.is_featured DESC, a.published_at DESC
                LIMIT :limit
            ");
            $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
            $stmt->execute();
            $rows = $stmt->fetchAll();
        }
        return array_map($this->hydrate(...), $rows);
    }

    /** @return list<array<string, mixed>> */
    public function featured(int $limit = 10): array
    {
        $sql = "
            SELECT a.id, a.title, a.summary, a.content, a.category_id, a.image_url,
                   a.published_at, a.read_minutes, a.is_featured, a.view_count,
                   au.name AS author_name
            FROM articles a
            INNER JOIN authors au ON au.id = a.author_id
            WHERE a.is_featured = 1
            ORDER BY a.published_at DESC
            LIMIT :limit
        ";
        $stmt = $this->pdo->prepare($sql);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        return array_map($this->hydrate(...), $stmt->fetchAll());
    }

    public function find(string $id): ?array
    {
        $sql = "
            SELECT a.id, a.title, a.summary, a.content, a.category_id, a.image_url,
                   a.published_at, a.read_minutes, a.is_featured, a.view_count,
                   au.name AS author_name
            FROM articles a
            INNER JOIN authors au ON au.id = a.author_id
            WHERE a.id = :id
        ";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch();
        return $row === false ? null : $this->hydrate($row);
    }

    /** @return list<array<string, mixed>> */
    public function related(string $articleId, int $limit = 4): array
    {
        $sql = "
            SELECT a.id, a.title, a.summary, a.content, a.category_id, a.image_url,
                   a.published_at, a.read_minutes, a.is_featured, a.view_count,
                   au.name AS author_name
            FROM articles a
            INNER JOIN authors au ON au.id = a.author_id
            WHERE a.category_id = (SELECT category_id FROM articles WHERE id = :id)
              AND a.id != :id
            ORDER BY a.published_at DESC
            LIMIT :limit
        ";
        $stmt = $this->pdo->prepare($sql);
        $stmt->bindValue('id', $articleId);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        return array_map($this->hydrate(...), $stmt->fetchAll());
    }

    /**
     * @return array{items: list<array<string, mixed>>, total: int}
     */
    public function search(string $query, ?string $categoryId, int $limit, int $offset): array
    {
        $bindings = [];
        $wheres = [];

        $q = trim($query);
        if ($q !== '') {
            $wheres[] = '(LOWER(a.title) LIKE :q OR LOWER(a.summary) LIKE :q OR LOWER(au.name) LIKE :q)';
            $bindings['q'] = '%' . mb_strtolower($q) . '%';
        }
        if ($categoryId !== null && $categoryId !== '' && $categoryId !== 'all') {
            $wheres[] = 'a.category_id = :category';
            $bindings['category'] = $categoryId;
        }
        $whereClause = $wheres === [] ? '' : 'WHERE ' . implode(' AND ', $wheres);

        $countSql = "
            SELECT COUNT(*) AS c
            FROM articles a
            INNER JOIN authors au ON au.id = a.author_id
            $whereClause
        ";
        $countStmt = $this->pdo->prepare($countSql);
        $countStmt->execute($bindings);
        $total = (int) ($countStmt->fetch()['c'] ?? 0);

        $sql = "
            SELECT a.id, a.title, a.summary, a.content, a.category_id, a.image_url,
                   a.published_at, a.read_minutes, a.is_featured, a.view_count,
                   au.name AS author_name
            FROM articles a
            INNER JOIN authors au ON au.id = a.author_id
            $whereClause
            ORDER BY a.published_at DESC
            LIMIT :limit OFFSET :offset
        ";
        $stmt = $this->pdo->prepare($sql);
        foreach ($bindings as $key => $value) {
            $stmt->bindValue($key, $value);
        }
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        return [
            'items' => array_map($this->hydrate(...), $stmt->fetchAll()),
            'total' => $total,
        ];
    }

    public function incrementViewCount(string $id): void
    {
        $stmt = $this->pdo->prepare(
            'UPDATE articles SET view_count = view_count + 1 WHERE id = :id'
        );
        $stmt->execute(['id' => $id]);
    }

    private function hydrate(array $row): array
    {
        return [
            'id'           => $row['id'],
            'title'        => $row['title'],
            'summary'      => $row['summary'],
            'content'      => $row['content'],
            'categoryId'   => $row['category_id'],
            'imageUrl'     => $row['image_url'],
            'author'       => $row['author_name'],
            'publishedAt'  => $row['published_at'],
            'readMinutes'  => (int) $row['read_minutes'],
            'isFeatured'   => (bool) $row['is_featured'],
            'viewCount'    => (int) $row['view_count'],
        ];
    }
}
