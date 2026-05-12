<?php

declare(strict_types=1);

namespace MobilHaber;

final class Router
{
    /** @var array<int, array{method: string, pattern: string, handler: callable}> */
    private array $routes = [];

    public function get(string $pattern, callable $handler): void
    {
        $this->add('GET', $pattern, $handler);
    }

    public function post(string $pattern, callable $handler): void
    {
        $this->add('POST', $pattern, $handler);
    }

    public function delete(string $pattern, callable $handler): void
    {
        $this->add('DELETE', $pattern, $handler);
    }

    public function add(string $method, string $pattern, callable $handler): void
    {
        $this->routes[] = [
            'method'  => strtoupper($method),
            'pattern' => $pattern,
            'handler' => $handler,
        ];
    }

    public function dispatch(string $method, string $path): void
    {
        $method = strtoupper($method);
        if ($method === 'OPTIONS') {
            Response::preflight();
            return;
        }

        $path = '/' . trim($path, '/');

        foreach ($this->routes as $route) {
            if ($route['method'] !== $method) {
                continue;
            }
            $params = [];
            if ($this->match($route['pattern'], $path, $params)) {
                ($route['handler'])($params);
                return;
            }
        }

        Response::notFound('Uç bulunamadı: ' . $method . ' ' . $path);
    }

    private function match(string $pattern, string $path, array &$params): bool
    {
        $regex = preg_replace('#\{([a-zA-Z_][a-zA-Z0-9_]*)\}#', '(?P<\1>[^/]+)', $pattern);
        $regex = '#^' . $regex . '$#u';
        if (preg_match($regex, $path, $matches) !== 1) {
            return false;
        }
        foreach ($matches as $key => $value) {
            if (!is_int($key)) {
                $params[$key] = $value;
            }
        }
        return true;
    }
}
