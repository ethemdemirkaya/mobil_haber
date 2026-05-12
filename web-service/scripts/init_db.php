<?php

declare(strict_types=1);

require_once __DIR__ . '/../src/Database.php';

use MobilHaber\Database;

$pdo = Database::connection();

$schemaPath = __DIR__ . '/../schema/001_schema.sql';
$seedPath   = __DIR__ . '/../schema/002_seed.sql';

if (!is_file($schemaPath) || !is_file($seedPath)) {
    fwrite(STDERR, "Şema dosyaları bulunamadı.\n");
    exit(1);
}

$schemaSql = file_get_contents($schemaPath) ?: '';
$seedSql   = file_get_contents($seedPath) ?: '';

echo "Şema uygulanıyor...\n";
$pdo->exec($schemaSql);

echo "Seed verisi yükleniyor...\n";
$pdo->exec($seedSql);

$count = (int) $pdo->query('SELECT COUNT(*) FROM articles')->fetchColumn();
echo "Tamamlandı. Toplam makale: {$count}\n";
