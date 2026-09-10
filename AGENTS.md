# AGENTS.md

## What this repository is

`infrax` is one executable bash bundle that turns a project manifest into a
production platform — services on five runtimes, their data and tools, on AWS,
GCP or any Linux box — through OpenTofu, Kubernetes, ArgoCD and Helm. `src/`
compiles into `target/{dev,release}/infrax.sh`: the core, the modules, and the
template tree as a checksum-verified payload. `bash src/main.sh` is the only
tool runner.

## The laws

- **Gravity.** Everything a runtime, a module or a cloud needs lives in data
  and templates — `src/template/runtime/<name>`, `src/template/module/<name>`,
  `src/template/tofu/<cloud>`, and `src/module/<cloud>.sh` behind
  `cloud <verb>`. The core is a thin pipeline over them: it never names a
  runtime, a module or a cloud. `if runtime ==` is a defect, and `check`
  hunts it.
- **One source per fact.** Every tunable, version, endpoint and path lives in
  `.env.example`; every secret is named in `.secret.example`; the two never
  share a key. The source carries no literal a manifest could own.
- **The manifest decides, infrax derives.** A project declares its stack,
  services, modules and options; infrax derives everything else and guesses
  nothing.
- **State is sacred.** A stateful resource keeps its name, labels and claim
  for life. A converge that would destroy one is refused; a restore lands
  beside the live database, never over it.
- **Secrets never surface.** Never printed, logged, committed, or rendered
  outside the build directory. `stdout` is data, `stderr` is diagnostics —
  nothing captured in `$(…)` ever shares stdout with a log line.
- **Laws, not hopes.** Every invariant becomes a check in `ci verify` (the
  consumer wall) or `bash src/main.sh check` (the forge wall) the day it is
  decided — and it must bite.

## Style

Bash 5 under `set -Eeuo pipefail`. `name () {` with a blank line after the
opening brace and before the closing one, no blank line between functions,
every `local` declared first, `[[ ]]` and quoted expansions always. A `## `
line above a function makes it a public command and is its help text. Loggers:
`step · info · succ · warn · err · die`. No comments beyond the `## ` doc lines
and ShellCheck directives.

## Non-negotiables

- `bash src/main.sh test --check` is green before any push: syntax,
  ShellCheck at the configured severity, payload integrity, no stray literals,
  every test.
- Guardrail files — `.github/**`, `src/forge/**`, `.env.example`,
  `.secret.example` — are never edited to make a change pass.
- Git is operator-driven: agents push or tag only on the operator's explicit
  order.

## Definition of done

The change builds, keeps every law it touched, adds the law for every
invariant it introduced, and reports honestly what was proven live and what
was only rendered.
