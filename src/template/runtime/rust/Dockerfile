ARG BUILD_IMAGE=rust:1.98.1-slim-trixie
ARG BASE_IMAGE=gcr.io/distroless/cc-debian13:nonroot

FROM ${BUILD_IMAGE} AS build

ARG BINARY=

WORKDIR /src

COPY . .

RUN --mount=type=cache,target=/usr/local/cargo/registry --mount=type=cache,target=/src/target \
    cargo build --release --locked \
    && name="${BINARY:-$(sed -n '/^\[package\]/,/^\[/s/^name *= *"\([^"]*\)".*/\1/p' Cargo.toml | head -n 1)}" \
    && install -D "target/release/${name}" /out/server

FROM ${BASE_IMAGE}

COPY --from=build /out/server /app/server

ENV PORT=8080

EXPOSE 8080

USER 65532:65532

ENTRYPOINT ["/app/server"]
