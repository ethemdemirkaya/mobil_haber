<?php

declare(strict_types=1);

namespace MobilHaber\Controllers;

use MobilHaber\Repositories\ArticleRepository;
use MobilHaber\Response;

final class ArticleController
{
    public function __construct(private readonly ArticleRepository $repo)
    {
    }

    public function index(): void
    {
        $category = isset($_GET['category']) ? (string) $_GET['category'] : null;
        $limit  = $this->intParam('limit', 20, 1, 100);
        $offset = $this->intParam('offset', 0, 0);

        $result = $this->repo->list($category, $limit, $offset);
        Response::ok($result['items'], [
            'total'  => $result['total'],
            'limit'  => $limit,
            'offset' => $offset,
        ]);
    }

    public function featured(): void
    {
        $limit = $this->intParam('limit', 10, 1, 50);
        Response::ok($this->repo->featured($limit));
    }

    public function show(string $id): void
    {
        $row = $this->repo->find($id);
        if ($row === null) {
            Response::notFound('Makale bulunamadı: ' . $id);
            return;
        }
        $this->repo->incrementViewCount($id);
        Response::ok($row);
    }

    public function related(string $id): void
    {
        $check = $this->repo->find($id);
        if ($check === null) {
            Response::notFound('Makale bulunamadı: ' . $id);
            return;
        }
        $limit = $this->intParam('limit', 4, 1, 20);
        Response::ok($this->repo->related($id, $limit));
    }

    public function search(): void
    {
        $query    = isset($_GET['q']) ? trim((string) $_GET['q']) : '';
        $category = isset($_GET['category']) ? (string) $_GET['category'] : null;
        $limit    = $this->intParam('limit', 20, 1, 100);
        $offset   = $this->intParam('offset', 0, 0);

        if ($query === '' && ($category === null || $category === '' || $category === 'all')) {
            Response::ok([], ['total' => 0, 'limit' => $limit, 'offset' => $offset]);
            return;
        }

        $result = $this->repo->search($query, $category, $limit, $offset);
        Response::ok($result['items'], [
            'total'  => $result['total'],
            'limit'  => $limit,
            'offset' => $offset,
            'query'  => $query,
        ]);
    }

    private function intParam(string $key, int $default, int $min = PHP_INT_MIN, int $max = PHP_INT_MAX): int
    {
        if (!isset($_GET[$key])) {
            return $default;
        }
        $value = filter_var($_GET[$key], FILTER_VALIDATE_INT);
        if ($value === false) {
            return $default;
        }
        return max($min, min($max, $value));
    }
}
