# 1x05 — Hardening Framework

A Linux server hardening framework written in Bash.
It applies a set of security measures (accounts, SSH, network, system) **idempotently**
and logs every action in JSON format.

---

## 1. Purpose

A freshly installed server is configured to be *functional*, not *secure*. Hardening
means reducing its attack surface: disabling what is unnecessary, restricting what is
required, and keeping a record of what was done.

This framework addresses three professional requirements:

| Requirement | Implementation |
|---|---|
| **Reproducibility** | A single script, runnable on N servers, producing the same state |
| **Idempotence** | Safe to re-run: identical final state, exit code 0 |
| **Traceability** | UTC-timestamped JSON log, consumable by a SIEM |

---

## 2. Layout

```
1x05_hardening/
├── harden.sh              # orchestrator — no business logic
├── config/
│   └── harden.cfg         # policy parameters (no secrets)
├── lib/
│   ├── system.sh          # logging, services, general file permissions
│   ├── identity.sh        # local accounts, password policy, sudo
│   ├── ssh.sh             # sshd daemon configuration
│   └── network.sh         # UFW and sysctl parameters
└── README.md
```

**Placement rule for a function:** *which subsystem of the server does it modify?*
That determines its file — not the order in which it is called.

`harden.sh` stays a pure orchestrator: it validates preconditions, loads configuration
and libraries, then calls functions in order. All hardening logic lives in `lib/`.

---

## 3. Usage

```bash
chmod +x harden.sh
sudo ./harden.sh
```

The script must be run from the project directory (`source` paths are relative — see
§7, Known limitations).

Log verification:

```bash
sudo cat /var/log/hardening.log
sudo ls -l /var/log/hardening.log     # expected: -rw------- root root
```

---

## 4. Configuration

All policy parameters live in `config/harden.cfg`. No value is hardcoded in the logic.

| Variable | Purpose |
|---|---|
| `LOG_FILE` | Path to the hardening log |
| `SSH_PORT` | SSH daemon listening port |
| `ALLOWED_SSH_USERS` | Accounts allowed to connect over SSH (**space**-separated) |
| `SSH_PERMIT_ROOT_LOGIN` | Whether direct root login is permitted |

**This file never contains secrets.** It contains *policy* — configuration decisions
meant to be audited and version-controlled. This is a direct application of
Kerckhoffs's principle: a system's security must never rest on the secrecy of its
design, but on its control mechanisms — here, file permissions and authentication.

The format of `ALLOWED_SSH_USERS` is dictated by its consumer: the `AllowUsers`
directive in `sshd_config` expects space-separated names. A comma would produce a
non-existent username — and lock the administrator out of the server.

---

## 5. Logging

### Format

One line per event, in JSON:

```json
{"timestamp":"2026-08-14T08:24:52Z","component":"framework","target":"/var/log/hardening.log","status":"initialized","details":"Hardening framework initialized"}
```

| Field | Content |
|---|---|
| `timestamp` | Date and time in **UTC**, ISO-8601 format |
| `component` | Subsystem involved (`framework`, `sshd`, `identity`…) |
| `target` | Object modified (file, service, account). `-` when not applicable |
| `status` | Outcome of the action (`initialized`, `changed`, `unchanged`, `failed`) |
| `details` | Human-readable message |

### Design decisions

**UTC and ISO-8601.** Local time is unusable for multi-server correlation, and the
daylight-saving rollback produces a duplicated hour — two distinct events can carry the
same timestamp. ISO-8601 also has the property of sorting correctly as plain text.

**Fixed-column schema.** All four fields are always present; a non-applicable field is
`-`. A log is consumed by a parser before it is read by a human: a stable schema can be
parsed, a variable one forces the consumer to guess. This follows the Apache/CLF
convention.

**`component` is mandatory.** Unlike the other three fields it has no default value:
the function fails if the caller omits it. A log line that does not say *who* is
speaking is unusable — better to fail loudly while writing the code than to silently
produce unusable data in production.

**Permissions `600 root:root`.** The log describes the machine's security configuration
in detail: it is a map of the attack surface and must be readable by root only.
Permissions are set once, at initialization, not on every `log()` call.

**Precondition errors go to `stderr`, not to the log.** The root check runs before
`$LOG_FILE` is defined, and at a point where writing to `/var/log/` is precisely
impossible. You cannot log the error that prevents logging.

### Idempotence and the log

Two consecutive runs produce two log lines. This does not violate idempotence:
idempotence applies to **convergence targets** — configuration files, services,
accounts — which the script brings to and keeps in a desired state. The log is an
**observation artifact**: being cumulative is its nature. An unchanged log after two
runs would instead indicate a write failure.

---

## 6. Safety guards

**`set -euo pipefail`**, placed immediately after the shebang:

- `-e`: abort on the first failing command. Without it, a script can print several
  `command not found` errors and still exit successfully — leaving the server
  half-hardened, which is more dangerous than an unhardened server, because it is
  believed to be protected.
- `-u`: a forgotten configuration variable becomes a fatal error instead of an empty
  string silently propagating into a firewall rule.
- `pipefail`: within a pipeline, the failure of an intermediate command is no longer
  masked by the success of the last one.

**Root check via `$EUID`**, written as a guard clause:

```bash
if [[ "$EUID" -ne 0 ]]; then
    echo "harden.sh: doit être exécuté en tant que root." >&2
    exit 1
fi
```

`$EUID` is a shell built-in variable. `whoami` is an external binary resolved through
`PATH` — therefore substitutable by an attacker who controls the environment. **A
security control never depends on `PATH`.**

The guard-clause form (early exit) keeps the nominal path flat, without nesting.

**No side effect before preconditions are validated.** `init_log()` creates a file in
`/var/log/`, so it is necessarily called *after* the root check.

---

## 7. Known limitations

**JSON escaping.** Fields are interpolated into the template without escaping. A double
quote inside `details` breaks the line structure. An attacker able to influence a
field's content could forge log entries, or make genuine ones unreadable to the SIEM
(**CWE-117, Improper Output Neutralization for Logs**).

This shares its root cause with SQL injection and XSS: mixing data and structure through
string concatenation. Using `printf` with a `%s` template already separates format from
data, but does not neutralize special characters *inside* a value.

Planned fix: delegate JSON construction to `jq`, which escapes correctly, or validate
inputs against an allow-list.

**Relative paths.** `harden.sh` loads its configuration and libraries by relative path,
so running it from another directory fails. Fix: resolve the script's own directory and
build absolute paths from it.

**Local log only.** Against an attacker who has obtained root, a local log offers no
guarantee: it can be rewritten. The only real defense is shipping entries to a separate
**machine** (rsyslog to a SIEM), since the lines have already left by the time of
compromise. Local mitigation: `chattr +a` (append-only).

---

## 8. Planned improvements

**Permissions `640 root:adm`.** Mode `600 root:root` makes the log unreadable to the
operations team, which creates an availability problem for the information itself (*bus
factor*). The `adm` group — dedicated to reading system logs — grants the team read
access without write access: authentication and authorization kept distinct, least
privilege applied.

**Configuration validation before reload.** Any change to `sshd_config` must be
validated with `sshd -t` before restarting the service: an invalid directive prevents
the daemon from starting and locks the administrator out of the server.

**Configuration management.** This framework is ad-hoc scripting: it expresses *how*. A
configuration management tool (Ansible, Puppet) expresses *what* — the desired state —
and handles idempotence, inventory and compliance reporting natively. The declarative
approach used here (remove every occurrence of a directive, then write it once, rather
than handling "absent", "present and correct", "present and wrong" and "commented out"
as separate cases) is a step in that direction.

---

## 9. Repository security

No SSH public key is committed to this repository. A public key is not a secret in the
cryptographic sense, but publishing it documents the attack surface: it reveals which
accounts exist and which machines reach them.

Likewise, moving the SSH port (`SSH_PORT`) reduces automated scan noise but **is not a
security measure**: it is security through obscurity. A port scan defeats it in
seconds.
