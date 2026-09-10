ARG BUILD_IMAGE=python:3.14.7-slim-trixie
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.12.12

FROM ${UV_IMAGE} AS uv

FROM ${BUILD_IMAGE} AS build

COPY --from=uv /uv /usr/local/bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=/app/.venv

WORKDIR /app

COPY pyproject.toml uv.lock* ./

RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-dev --no-install-project

COPY . .

RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-dev

FROM ${BUILD_IMAGE}

RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home app

WORKDIR /app

COPY --from=build --chown=app:app /app /app

ENV PATH="/app/.venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

EXPOSE 8080

USER 10001

CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
