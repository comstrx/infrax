ARG BUILD_IMAGE=golang:1.27.1-trixie
ARG BASE_IMAGE=gcr.io/distroless/static-debian13:nonroot

FROM ${BUILD_IMAGE} AS build

ARG MAIN=.

WORKDIR /src

COPY go.mod go.sum* ./

RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server "${MAIN}"

FROM ${BASE_IMAGE}

COPY --from=build /out/server /app/server

ENV PORT=8080

EXPOSE 8080

USER 65532:65532

ENTRYPOINT ["/app/server"]
