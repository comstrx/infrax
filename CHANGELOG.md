# Changelog

## 0.2.0

The first release under the infrax name — a platform for any number of services, not one app.

- **The manifest.** A project commits `infrax.env` (and `infrax.<stack>.env` per stack): `SERVICES`, `MODULES`, and `SERVICE_<NAME>_<KEY>` for each service. Precedence: `flags > process env > JSON_ENV > --config files > infrax.<stack>.env > infrax.env > defaults`; inside one file the last line wins. The manifest law refuses an unknown runtime, module, key, call or use before anything runs, and names every fault at once.
- **Five runtimes.** `laravel` · `rust` · `go` · `python` · `node` — each a `profile.env`, a Dockerfile and a binding style under `src/template/runtime/`. A service overrides any profile key; a runtime key (`GO_PORT`) overrides it for every service on that runtime.
- **Six modules.** `postgresql` · `mysql` · `redis` · `storage` · `pgadmin4` · `phpmyadmin`. Every service that uses a database gets its own database and user, provisioned by a PreSync job and passworded from the root secret — deterministic, never shared. Bindings speak the runtime's language: `DB_*` / `REDIS_*` / `FILESYSTEM_DISK` for laravel, `DATABASE_URL` / `REDIS_URL` / `STORAGE_*` for the rest.
- **Zero-trust by declaration.** A service admits only the gateway (when public), the services that declare they call it, and monitoring. A module admits only its services, its tools and its exporters. Callers learn their callees as `<NAME>_URL=http://<name>:<port>`.
- **Names.** Public hosts are `HOST_PREFIX` + label under `BASE_DOMAIN`. DNS touches a name only when this stack answers on it, inside the prefix, under the domain — never the apex, never a neighbour's record.
- **Two clouds.** `aws` and `gcp` behind one verb set (`module/<cloud>.sh`); OpenTofu stacks for both: `light` (one VM running k3s, registry, per-service buckets) and `full` (EKS / GKE, RDS / Cloud SQL per managed database, workload identity per service, backup identities). Every stack is `tofu validate` clean on AWS provider 6.64 and Google provider 8.2.
- **Charts.** `service`, `data` and `tool` replace the single-app platform chart; the app-of-apps deploys every service (wave 1), every data module (wave 0) and every tool (wave 2) from the values the seed derives.
- **Backups.** A nightly dump of every bound database per module, shipped to the backup bucket (object stacks) or a volume (standard), restorable into a side database.
- **Pins.** Kubernetes 1.36 · ArgoCD v3.5.2 · Envoy Gateway 1.9.1 · cert-manager v1.21.1 · Helm v4.3.0 · OpenTofu 1.12.6 · PostgreSQL 18.6 · MySQL 8.4.11 · Redis 8.10.1 · kube-prometheus-stack 90.0.0 · Loki 7.3.0.
- **The forge.** `check` keeps the core neutral — no runtime, module or cloud named outside `src/template` and `module/<cloud>.sh` — and every key in `FORGE_KEYS` read by the forge itself. Tests run against a fixture project in `tests/fixture`.
