<?php

declare(strict_types=1);

namespace MobilHaber\Repositories;

use MobilHaber\Database;
use PDO;

final class CategoryRepository
{
    private PDO $pdo;

    public function __construct()
    {
        $this->pdo = Database::connection();
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function all(): array
    {
        $stmt = $this->pdo->query(
            'SELECT id, name, icon, color, sort_order FROM categories ORDER BY sort_order ASC'
        );
        return array_map($this->hydrate(...), $stmt->fetchAll());
    }

    public function find(string $id): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT id, name, icon, color, sort_order FROM categories WHERE id = :id'
        );
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch();
        return $row === false ? null : $this->hydrate($row);
    }

    private function hydrate(array $row): array
    {
        return [
            'id'        => $row['id'],
            'name'      => $row['name'],
            'icon'      => $row['icon'],
            'color'     => $row['color'],
            'sortOrder' => (int) $row['sort_order'],
        ];
    }
}
