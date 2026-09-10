# ✨ InfraX

<div align="center">
  <br/>
  <img height="250" src="https://github.com/user-attachments/assets/c07adfaf-427a-422f-94be-1af860a18ff3" />
  <br/>
  <br/>
  <br/>
</div>

[![License: MIT OR Apache-2.0](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue.svg)](#license)
[![Bash 5+](https://img.shields.io/badge/bash-5%2B-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![ShellCheck](https://img.shields.io/badge/shellcheck-clean-brightgreen.svg)](https://www.shellcheck.net)
[![CI](https://github.com/comstrx/infrax/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/comstrx/infrax/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/comstrx/infrax?sort=semver)](https://github.com/comstrx/infrax/releases/latest)

`infrax` turns one manifest into a production platform — any number of services on five runtimes, their databases, caches, storage and tools, on AWS, GCP or any Linux box. OpenTofu provisions, Kubernetes runs, ArgoCD reconciles, Helm shapes; TLS, DNS, backups, observability and a verify wall come with it.

## Overview

One executable file carries the whole platform: the bash core, every module, and the template tree — Helm charts, ArgoCD apps, OpenTofu stacks, Dockerfiles — as a checksum-verified payload. A project declares what it runs; infrax derives the rest and guesses nothing.

| Axis     | Choices                                                                                             |
| -------- | --------------------------------------------------------------------------------------------------- |
| Services | `laravel` · `rust` · `go` · `python` · `node` — as many as the project names, each reachable by its name |
| Modules  | `postgresql` · `mysql` · `redis` · `storage` · `pgadmin4` · `phpmyadmin` — in the cluster or managed by the cloud |
| Stacks   | `light` one VM running k3s · `standard` any Linux over ssh · `full` managed Kubernetes and databases |
| Clouds   | `aws` · `gcp`                                                                                       |

Every service gets its own image, workloads, Service, autoscaler, disruption budget, network policy, route, migration hook and credentials. Every module a service uses is bound to it — its own database and user — in the environment names its runtime expects. Every call a service declares is the only door the network opens for it.

## Install

```bash
curl -fsSL https://github.com/comstrx/infrax/releases/latest/download/infrax.sh -o ~/.local/bin/infrax
chmod +x ~/.local/bin/infrax
infrax --help
```

In a workflow — no token, the release's `SHA256SUMS` verify it:

```yaml
- uses: comstrx/infrax@v0.2.1
- run: infrax -s light ci release
  env:
    JSON_ENV: ${{ toJSON(secrets) }}
```

## Declare

`infrax.env` at the root of the project repo — committed, no secrets:

```bash
PROJECT=shop
CLOUD=aws
AWS_REGION=eu-north-1
BASE_DOMAIN=example.com
HOST_PREFIX=shop-

SERVICES=api catalog
MODULES=postgresql redis storage

SERVICE_API_RUNTIME=laravel
SERVICE_API_PATH=services/api
SERVICE_API_HOST=api
SERVICE_API_USES=postgresql redis storage
SERVICE_API_CALLS=catalog
SERVICE_API_PROCESSES=web horizon scheduler

SERVICE_CATALOG_RUNTIME=go
SERVICE_CATALOG_PATH=services/catalog
SERVICE_CATALOG_USES=postgresql redis
```

`api` answers on `shop-api.example.com`; `catalog` stays inside the cluster, reachable as `http://catalog:8080` by `api` alone. `infrax.<stack>.env` overlays one stack. Secrets — cloud keys, root passwords, each service's own environment — come from a file or the process environment, never the repo; `.secret.example` names every one.

Precedence: `flags > process env > JSON_ENV > --config files > infrax.<stack>.env > infrax.env > built-in defaults`.

## Use

```bash
infrax -l                                        # every module with every command
infrax -s light ci verify                        # the wall: lint, render matrix, templates, workflows, leaks, tofu
infrax -s light ci release                       # converge, build, prove, push, scan, vendor, bump, deploy
infrax -s light app run api -- php artisan about # one command on the live release of one service
infrax -s full tofu plan
infrax audit all
```

The bundle acts on the git repo around you (or `--repo <dir>`): it writes the gitops path (`DEPLOY_PATH`, default `deploy/`) that ArgoCD reads — the vendored charts, the bundle itself, and the values of every service and module — and keeps its working files under `.infrax/`.

## Develop

```bash
bash src/main.sh build            # target/dev/infrax.sh — tests included, templates read live from src/
bash src/main.sh test --check     # syntax + shellcheck + payload integrity + no stray literals + the tests
bash src/main.sh test "config*"   # a glob of tests; --list shows what would run
bash src/main.sh build-release    # target/release/infrax.sh + SHA256SUMS (tests stripped)
bash src/main.sh install          # verified against SHA256SUMS, into INFRAX_INSTALL_DIR
bash src/main.sh release          # GitHub release of the bundle, notes from CHANGELOG.md
```

Layout: `src/forge` the build system · `src/core` config, cli, payload, helpers · `src/module` one file per concern · `src/template` runtimes, modules, charts, apps, stacks · `tests/` functions named `test_*`, run inside the dev bundle.

## Update

```bash
infrax self version
infrax self update            # the latest release, checksum verified
infrax self update v0.2.1
```

## Community

- [Issues](https://github.com/comstrx/infrax/issues)
- [Discussions](https://github.com/comstrx/infrax/discussions)
- [Contributing](https://github.com/comstrx/infrax/blob/main/CONTRIBUTING.md)
- [Security](https://github.com/comstrx/infrax/blob/main/SECURITY.md)
- [Support](https://github.com/comstrx/infrax/blob/main/SUPPORT.md)

## License

<code>infrax</code> is dual-licensed under either
[MIT](https://github.com/comstrx/infrax/blob/main/LICENSE-MIT) or
[Apache-2.0](https://github.com/comstrx/infrax/blob/main/LICENSE-APACHE), at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in this work by you, as defined in the Apache-2.0 license, shall be
dual-licensed as above, without any additional terms or conditions.
