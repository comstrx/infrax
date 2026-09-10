ARG BUILD_IMAGE=dunglas/frankenphp:1.12.7-php8.5-trixie
ARG COMPOSER_IMAGE=composer:2.10.3
ARG PHP_EXT_VERSION=2.11.12

FROM ${COMPOSER_IMAGE} AS composer

FROM ${BUILD_IMAGE} AS base

ARG PHP_EXT_VERSION

ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/download/${PHP_EXT_VERSION}/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
    pcntl pdo_pgsql pgsql pdo_mysql redis opcache \
    gd exif intl zip bcmath

RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends libcap2-bin \
    && setcap -r /usr/local/bin/frankenphp \
    && apt-get purge -y libcap2-bin \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

FROM base AS vendor

COPY --from=composer /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY composer.json composer.lock ./

RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --no-scripts --no-autoloader

COPY . .

RUN composer dump-autoload --optimize --no-dev --classmap-authoritative

FROM base AS app

WORKDIR /app

COPY --from=vendor /app /app

RUN printf '%s\n' \
    'expose_php = 0' \
    'memory_limit = 512M' \
    'upload_max_filesize = 25M' \
    'post_max_size = 32M' \
    'realpath_cache_size = 8M' \
    'realpath_cache_ttl = 600' \
    'opcache.memory_consumption = 256' \
    'opcache.interned_strings_buffer = 32' \
    'opcache.max_accelerated_files = 20011' \
    'opcache.validate_timestamps = 0' \
    > "${PHP_INI_DIR}/conf.d/zz-runtime.ini"

RUN mkdir -p storage/framework/views storage/framework/cache/data storage/framework/sessions storage/logs storage/app/public bootstrap/cache \
    && ln -sfn ../storage/app/public public/storage \
    && cp vendor/laravel/octane/src/Commands/stubs/frankenphp-worker.php public/frankenphp-worker.php \
    && chown -R www-data:www-data storage bootstrap/cache public/storage

ENV PORT=8000 \
    OCTANE_WORKERS=auto \
    OCTANE_MAX_REQUESTS=500 \
    XDG_CONFIG_HOME=/tmp \
    XDG_DATA_HOME=/tmp

EXPOSE 8000

USER www-data

ENTRYPOINT ["sh", "-c", "exec php artisan octane:frankenphp --host=0.0.0.0 --port=${PORT} --workers=${OCTANE_WORKERS} --max-requests=${OCTANE_MAX_REQUESTS}"]
