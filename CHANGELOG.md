# Changelog

## 0.2.5

- `CVE_IGNORE` accepts reviewed findings by name (`CVE-…`, `GHSA-…`, space or comma separated) — the gate still prints them, marked accepted, and any finding not named still blocks. `CVE_ALLOW` stays the one-release override.
- k3s installs a pinned release (`K3S_VERSION=v1.36.4+k3s1`) straight from GitHub instead of resolving a channel through update.k3s.io — reproducible, and deaf to that server's outages. Empty `K3S_VERSION` still follows the `K8S_VERSION` channel.

## 0.2.4

- The Debian-based runtime images (laravel, python) take the distribution's security updates at build time — a base image a week old no longer ships a CRITICAL the archive has already fixed. The distroless finals (go, rust, node) move with their base.
- The CVE gate prints every fixable CRITICAL it blocks on — CVE, package, installed → fixed, target — so "review them" has something to review.

## 0.2.3

- The CVE gate judges every image by one rule — trivy, fixable CRITICAL only — wherever the image lives. ECR's basic scan counted every CRITICAL, fixed or not (a trixie image carries ~50 kernel-header CVEs no container can reach), so the same image passed on one registry and blocked on another. The cloud `registry_criticals` verbs are gone.

## 0.2.2

- A tool's own login is flagged `ROOT_LOGIN=true` in its `module.env`, not `PASSWORD=true` — the flag shared its override name with the secret `<MODULE>_PASSWORD`, so a set password hid the flag and pgadmin4 never received its login.
- The examples law knows the root password every module holds (`<MODULE>_PASSWORD` for each store, and each tool with `ROOT_LOGIN=true`) and scans the bundle's code without its tests — the dev bundle can no longer pass what the release fails.
- `service_host` takes a service's first public name from the whole list — a service answering on two names no longer breaks the pipe that fed it.

## 0.2.1

- aws derives the ECR registry from the account its credentials act in (asked once, remembered under the build dir) — the render matrix and the first release need neither an applied stack nor a hand-set `ECR_REGISTRY`. A pinned `ECR_REGISTRY` still wins.

## 0.2.0

The first release under the infrax name — a platform for any number of services, not one app.

- **The manifest.** A project commits `infrax.env` (and `infrax.<stack>.env` per stack): `SERVICES`, `MODULES`, and `SERVICE_<NAME>_<KEY>` for each service. Precedence: `flags > process env > JSON_ENV > --config files > infrax.<stack>.env > infrax.env > defaults`; inside one file the last line wins. The manifest law refuses an unknown runtime, module, key, call or use before anything runs, and names every fault at once.
- **Five runtimes.** `laravel` · `rust` · `go` · `python` · `node` — each a `profile.env`, a Dockerfile and a binding style under `src/template/runtime/`. A service overrides any profile key; a runtime key (`GO_PORT`) overrides it for every service on that runtime.
- **Six modules.** `postgresql` · `mysql` · `redis` · `storage` · `pgadmin4` · `phpmyadmin`. Every service that uses a database gets its own database and user, provisioned by a PreSync job and passworded from the root secret — deterministic, never shared. Bindings speak the runtime's language: `DB_*` / `REDIS_*` / `FILESYSTEM_DISK` for laravel, `DATABASE_URL` / `REDIS_URL` / `STORAGE_*` for the rest.
- **Zero-trust by declaration.** A service admits only the gateway (when public), the services that declare they call it, and monitoring. A module admits only its services, its tools and its exporters. Callers learn their callees as `SERVICE_<NAME>_URL=http://<name>:<port>`.
- **The action.** `uses: comstrx/infrax@v0.2.0` installs the bundle of that tag in a workflow — checksum verified, no token, the vendored copy in the gitops path when it matches.
- **Names.** Public hosts are `HOST_PREFIX` + label under `BASE_DOMAIN`. DNS touches a name only when this stack answers on it, inside the prefix, under the domain — never the apex, never a neighbour's record.
- **Two clouds.** `aws` and `gcp` behind one verb set (`module/<cloud>.sh`); OpenTofu stacks for both: `light` (one VM running k3s, registry, per-service buckets) and `full` (EKS / GKE, RDS / Cloud SQL per managed database, workload identity per service, backup identities). Every stack is `tofu validate` clean on AWS provider 6.64 and Google provider 8.2.
- **Charts.** `service`, `data` and `tool` replace the single-app platform chart; the app-of-apps deploys every service (wave 1), every data module (wave 0) and every tool (wave 2) from the values the seed derives.
- **Backups.** A nightly dump of every bound database per module, shipped to the backup bucket (object stacks) or a volume (standard), restorable into a side database.
- **Pins.** Kubernetes 1.36 · ArgoCD v3.5.2 · Envoy Gateway 1.9.1 · cert-manager v1.21.1 · Helm v4.3.0 · OpenTofu 1.12.6 · PostgreSQL 18.6 · MySQL 8.4.11 · Redis 8.10.1 · kube-prometheus-stack 90.0.0 · Loki 7.3.0.
- **The forge.** `check` keeps the core neutral — no runtime, module or cloud named outside `src/template` and `module/<cloud>.sh` — and every key in `FORGE_KEYS` read by the forge itself. Tests run against a fixture project in `tests/fixture`.
