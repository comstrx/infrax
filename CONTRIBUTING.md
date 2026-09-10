# Contributing

Welcome to `infrax` 👋 We love high-quality contributions.

- This guide is the shortest path from idea -> merged PR.

## Where to go

| You want to...                    | Use...                                                                   |
| --------------------------------- | ------------------------------------------------------------------------ |
| Ask a question / propose a design | 💬 [Discussions](https://github.com/comstrx/infrax/discussions)          |
| Report a reproducible bug         | 🐞 [Issues](https://github.com/comstrx/infrax/issues)                    |
| Report a security issue (private) | 🔒 [Security](https://github.com/comstrx/infrax/security/advisories/new) |

[Repository](https://github.com/comstrx/infrax)

---

## What makes a great contribution

- Small and focused: one logical change per PR when possible.
- Verified: tests updated (or a clear explanation why not).
- Clear: describe the why, not just the what.
- Documented: if behavior, a command, or a manifest key changes, update the README and the examples.
- Neutral: a runtime, module or cloud arrives as data and templates, never as a branch in the core.

If you are unsure about scope, start with a short [discussion](https://github.com/comstrx/infrax/discussions) first.

---

## Getting started

1. Fork the repo and clone it locally.
2. Create a new branch for your change.
3. Follow the development instructions in the [README](https://github.com/comstrx/infrax/blob/main/README.md#develop) and the laws in [AGENTS.md](https://github.com/comstrx/infrax/blob/main/AGENTS.md).
4. Make your change, add/adjust tests/docs as needed.
5. Open a PR and follow the [PR template/checklist](https://github.com/comstrx/infrax/blob/main/.github/PULL_REQUEST_TEMPLATE.md).

---

## PR checklist (fast reviews)

Before opening a PR, make sure:

- ✅ The change is easy to understand and review
- ✅ `bash src/main.sh test --check` passes and new behavior is covered (when applicable)
- ✅ Every new tunable lives in `.env.example`, every new secret is named in `.secret.example`
- ✅ Docs/examples match the new behavior (if changed)

---

## Code of Conduct

By participating, you agree to follow the [Code of Conduct](https://github.com/comstrx/infrax/blob/main/CODE_OF_CONDUCT.md).

## Security

Do not disclose security issues publicly. [Report them privately](https://github.com/comstrx/infrax/security/advisories/new).
