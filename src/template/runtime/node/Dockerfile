ARG BUILD_IMAGE=node:24.21.0-trixie-slim
ARG BASE_IMAGE=gcr.io/distroless/nodejs24-debian13:nonroot

FROM ${BUILD_IMAGE} AS build

WORKDIR /app

COPY package.json package-lock.json* ./

RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

COPY . .

RUN npm run build --if-present \
    && npm prune --omit=dev --no-audit --no-fund \
    && main="$(node -p "require('./package.json').main || 'index.js'")" \
    && { [ "${main}" = "server.js" ] || ln -sfn "${main}" server.js; }

FROM ${BASE_IMAGE}

WORKDIR /app

COPY --from=build /app /app

ENV PORT=8080

EXPOSE 8080

USER 65532:65532

CMD ["server.js"]
