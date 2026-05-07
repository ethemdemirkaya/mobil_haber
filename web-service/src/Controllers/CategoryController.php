<?php

declare(strict_types=1);

namespace MobilHaber\Controllers;

use MobilHaber\Repositories\CategoryRepository;
use MobilHaber\Response;

final class CategoryController
{
    public function __construct(private readonly CategoryRepository $repo)
    {
    }

    public function index(): void
    {
        Response::ok($this->repo->all());
    }

    public function show(string $id): void
    {
        $row = $this->repo->find($id);
        if ($row === null) {
            Response::notFound('Kategori bulunamadı: ' . $id);
            return;
        }
        Response::ok($row);
    }
}
