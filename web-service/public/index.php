<?php

declare(strict_types=1);

require_once __DIR__ . '/../src/Database.php';
require_once __DIR__ . '/../src/Response.php';
require_once __DIR__ . '/../src/Router.php';
require_once __DIR__ . '/../src/Cache/FileCache.php';
require_once __DIR__ . '/../src/External/HttpClient.php';
require_once __DIR__ . '/../src/External/ExternalSourceInterface.php';
foreach (glob(__DIR__ . '/../src/External/*Source.php') ?: [] as $f) {
    require_once $f;
}
require_once __DIR__ . '/../src/External/SourceRegistry.php';
require_once __DIR__ . '/../src/Repositories/CategoryRepository.php';
require_once __DIR__ . '/../src/Repositories/ArticleRepository.php';
require_once __DIR__ . '/../src/Repositories/BookmarkRepository.php';
require_once __DIR__ . '/../src/Controllers/CategoryController.php';
require_once __DIR__ . '/../src/Controllers/ArticleController.php';
require_once __DIR__ . '/../src/Controllers/BookmarkController.php';
require_once __DIR__ . '/../src/Controllers/ExternalNewsController.php';

use MobilHaber\Controllers\ArticleController;
use MobilHaber\Controllers\BookmarkController;
use MobilHaber\Controllers\CategoryController;
use MobilHaber\Controllers\ExternalNewsController;
use MobilHaber\External\SourceRegistry;
use MobilHaber\Repositories\ArticleRepository;
use MobilHaber\Repositories\BookmarkRepository;
use MobilHaber\Repositories\CategoryRepository;
use MobilHaber\Response;
use MobilHaber\Router;

set_exception_handler(static function (\Throwable $e): void {
    error_log('[mobil_haber] ' . $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
    Response::error('Sunucu hatası: ' . $e->getMessage(), 500, 'server_error');
});

$categoryController = new CategoryController(new CategoryRepository());
$articleController  = new ArticleController(new ArticleRepository());
$bookmarkController = new BookmarkController(new BookmarkRepository());
$externalController = new ExternalNewsController(new SourceRegistry());

$router = new Router();

$router->get('/health', static function (): void {
    Response::ok(['status' => 'ok', 'service' => 'mobil_haber-api', 'time' => date(DATE_ATOM)]);
});

$router->get('/categories', $categoryController->index(...));
$router->get('/categories/{id}', static fn(array $p) => $categoryController->show($p['id']));

$router->get('/articles', $articleController->index(...));
$router->get('/articles/featured', $articleController->featured(...));
$router->get('/articles/search', $articleController->search(...));
$router->get('/articles/{id}', static fn(array $p) => $articleController->show($p['id']));
$router->get('/articles/{id}/related', static fn(array $p) => $articleController->related($p['id']));

$router->get('/bookmarks', $bookmarkController->index(...));
$router->post('/bookmarks', $bookmarkController->add(...));
$router->delete('/bookmarks', $bookmarkController->clear(...));
$router->delete('/bookmarks/{id}', static fn(array $p) => $bookmarkController->remove($p['id']));

// Dış kaynaklar (RSS + ücretsiz API'ler + opsiyonel anahtarlı sağlayıcılar)
$router->get('/external/sources',   $externalController->sources(...));
$router->get('/external/health',    $externalController->health(...));
$router->get('/external/articles',  $externalController->articles(...));
$router->get('/external/aggregate', $externalController->aggregate(...));

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri    = $_SERVER['REQUEST_URI'] ?? '/';
$path   = parse_url($uri, PHP_URL_PATH) ?: '/';

// Strip script base if served without rewrite (e.g. /web-service/public/index.php/articles)
$scriptName = $_SERVER['SCRIPT_NAME'] ?? '';
if ($scriptName !== '' && str_starts_with($path, $scriptName)) {
    $path = substr($path, strlen($scriptName));
}
// Strip /api prefix if proxied behind one
if (str_starts_with($path, '/api')) {
    $path = substr($path, 4);
}

$router->dispatch($method, $path === '' ? '/' : $path);
