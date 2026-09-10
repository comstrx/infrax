# Support

Welcome! This page is the fastest way to get help with `infrax` with the least back-and-forth.

## Choose the right place

| You want to...                    | Go to...                                                                 |
| --------------------------------- | ------------------------------------------------------------------------ |
| Ask a question / discuss design   | 💬 [Discussions](https://github.com/comstrx/infrax/discussions)          |
| Report a reproducible bug         | 🐞 [Issues](https://github.com/comstrx/infrax/issues)                    |
| Report a security issue (private) | 🔒 [Security](https://github.com/comstrx/infrax/security/advisories/new) |
| Read docs / guides                | 📚 [README](https://github.com/comstrx/infrax/blob/main/README.md)       |
| Review recent changes             | 🧾 [Changelog](https://github.com/comstrx/infrax/blob/main/CHANGELOG.md) |

---

## Before you post (2 minutes)

- Search existing Issues/Discussions (duplicates slow everyone down).
- Confirm you are on the latest release (`infrax self update`) — many bugs are already fixed.
- Reduce to a minimal reproduction (the smallest manifest and the one command that fails).

If you cannot reproduce it reliably, we probably cannot fix it reliably.

---

## Bug reports that get solved fast

When opening an Issue, please include:

- What happened vs what you expected
- Minimal repro: the manifest (secrets removed) + the exact command
- Versions:
  - `infrax --version`
  - `bash --version`, `kubectl version --client`, `helm version`, `tofu version`
- Environment: OS + architecture, cloud, stack
- Output: exact error/logs (copy as text, not screenshots)
- If relevant: `infrax secrets check` (it prints names, never values)

Helpful links (if available):

- [Bug report template](https://github.com/comstrx/infrax/issues/new?template=bug_report.md)
- [Feature request template](https://github.com/comstrx/infrax/issues/new?template=feature_request.md)

---

## Slow releases (we love those reports too)

If a release or a converge got slower, please add:

- the stack, the cloud, and the number of services and modules
- which step took the time (the release line prints every step)
- before vs after durations

---

## Scope and expectations

We are happy to help with:

- ✅ Reproducible bugs and regressions
- ✅ Documentation gaps and examples
- ✅ Clarifying intended behavior / manifest keys
- ✅ Release and converge time regressions

We usually cannot help with:

- ❌ "It is broken" with no repro, versions, or logs
- ❌ Debugging hand-edited generated files or heavily modified forks (please reproduce on upstream)
- ❌ Security reports via public Issues (use the Security Policy link)

`infrax` is community-driven. There is no guaranteed SLA, but clear reports get the fastest response.

Thanks for helping keep the project sharp. 🧠
