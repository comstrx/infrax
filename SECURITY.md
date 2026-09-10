# Security Policy

We take security seriously.

- Please report vulnerabilities privately.
- Do not open public Issues for security reports.

## Report a vulnerability

Preferred (fastest):

- [GitHub Private Vulnerability Reporting / Security Advisories](https://github.com/comstrx/infrax/security/advisories/new) 🔒

If the above is not available, email the maintainer privately: <comstrx@gmail.com>

## What belongs here

✅ Security reports include:

- secret exposure: a value printed, logged, committed, or rendered where it should not be
- privilege escalation or lateral movement a generated manifest allows (RBAC, network policy, cloud identity)
- supply-chain or verification issues with clear impact (bundle checksum, template payload, image provenance)
- unsafe defaults that affect real deployments

❌ Not security reports (use Issues/Discussions instead):

- general bugs, feature requests, usage questions -> [Issues](https://github.com/comstrx/infrax/issues) / [Discussions](https://github.com/comstrx/infrax/discussions)
- failures without security impact details

## Include this (makes triage fast)

- affected module, template or stack + the release or commit you are on (`infrax --version`)
- impact (what can an attacker do?) + assumptions / threat model
- minimal reproduction or PoC (safe and small)
- environment details (OS/arch, `bash --version`, cloud, stack)
- relevant logs / error output

🚫 Do not include secrets (tokens, private keys, credentials, personal data). `infrax secrets check` names what resolves without printing a value.

## Responsible disclosure

- Please avoid public disclosure until a fix is available.
- We will coordinate on a timeline, patch, and advisory when confirmed.
- When appropriate, we disclose via releases and GitHub Security Advisories.
