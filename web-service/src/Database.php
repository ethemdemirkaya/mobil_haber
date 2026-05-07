<?php

declare(strict_types=1);

namespace MobilHaber;

use PDO;
use RuntimeException;

final class Database
{
    private static ?PDO $instance = null;

    public static function connection(): PDO
    {
        if (self::$instance instanceof PDO) {
            return self::$instance;
        }

        $driver = getenv('DB_DRIVER') ?: 'sqlite';

        if ($driver === 'sqlite') {
            $path = getenv('DB_PATH') ?: __DIR__ . '/../storage/mobil_haber.sqlite';
            $dir = dirname($path);
            if (!is_dir($dir) && !mkdir($dir, 0775, true) && !is_dir($dir)) {
                throw new RuntimeException("Veritabanı dizini oluşturulamadı: $dir");
            }
            $dsn = 'sqlite:' . $path;
            $pdo = new PDO($dsn, null, null, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]);
            $pdo->exec('PRAGMA foreign_keys = ON;');
            $pdo->exec('PRAGMA journal_mode = WAL;');
        } elseif ($driver === 'mysql') {
            $host = getenv('DB_HOST') ?: '127.0.0.1';
            $port = getenv('DB_PORT') ?: '3306';
            $name = getenv('DB_NAME') ?: 'mobil_haber';
            $user = getenv('DB_USER') ?: 'root';
            $pass = getenv('DB_PASS') ?: '';
            $dsn = "mysql:host=$host;port=$port;dbname=$name;charset=utf8mb4";
            $pdo = new PDO($dsn, $user, $pass, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
        } else {
            throw new RuntimeException("Desteklenmeyen DB_DRIVER: $driver");
        }

        self::$instance = $pdo;
        return $pdo;
    }
}
