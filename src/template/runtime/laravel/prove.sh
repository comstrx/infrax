cmp -s public/frankenphp-worker.php vendor/laravel/octane/src/Commands/stubs/frankenphp-worker.php || { echo "the octane worker is missing or is not the one this octane ships"; exit 1; }
test "$(readlink public/storage)" = "../storage/app/public" || { echo "public/storage points outside the image"; exit 1; }
test -w storage/logs || { echo "storage is not writable by the runtime user"; exit 1; }
php -r 'exit(extension_loaded("pcntl") && extension_loaded("pdo_pgsql") && extension_loaded("pdo_mysql") && extension_loaded("redis") ? 0 : 1);' || { echo "an extension the app runs on is missing"; exit 1; }
