# 1x05 — Hardening Framework

A Linux server hardening framework written in Bash. It translates the **STIG-2024**
security policy into technical configuration, applies it **idempotently**, and logs
every action in JSON.

---

## 1. Purpose

A freshly installed server is configured to be *functional*, not *secure*. Hardening
reduces its attack surface: disabling what is unnecessary, restricting what is
required, and recording what was done.

A security policy is written in plain English by a security team ("passwords must be
strong"). This framework is the translation of that policy into commands a machine can
execute — and re-execute — without drift.

| Requirement | Implementation |
|---|---|
| **Reproducibility** | One script, runnable on N servers, producing the same state |
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
│   ├── system.sh          # logging, package management
│   ├── identity.sh        # accounts, password policy, lockout
│   ├── ssh.sh             # sshd daemon configuration
│   └── network.sh         # firewall policy and sysctl
└── README.md
```

**Placement rule for a function:** *which subsystem of the server does it modify?*
That determines its file — not the order in which it is called.

---

## 3. Usage

```bash
chmod +x harden.sh
sudo ./harden.sh
```

The script resolves its own directory, so it can be invoked from anywhere:

```bash
sudo /path/to/1x05_hardening/harden.sh
```

Verification:

```bash
sudo cat /var/log/hardening.log
sudo cat /etc/hardening/firewall.rules
grep -E "^net\.ipv4\." /etc/sysctl.conf
```

---

## 4. Policy coverage

### Network domain

| Rule | Implementation |
|---|---|
| N-01 | `/etc/hardening/firewall.rules` regenerated with `DEFAULT_INPUT=deny`, `DEFAULT_OUTPUT=allow` |
| N-02 | `ALLOW_TCP` entries for the configured SSH port, plus 80/443 when enabled |
| N-03 | `net.ipv4.ip_forward=0`, `net.ipv4.conf.all.accept_redirects=0`, `net.ipv4.icmp_echo_ignore_all=1` persisted in `/etc/sysctl.conf` |

The firewall policy is written as a persistent configuration file, not applied to a
running service — as specified by the lab statement.

Kernel parameters are written to `/etc/sysctl.conf` rather than applied with
`sysctl -w`: a runtime setting is lost at the next reboot, which would leave the server
believed to be hardened while it is not.

### SSH domain

| Rule | Implementation |
|---|---|
| S-01 | `PasswordAuthentication no`, `PubkeyAuthentication yes` |
| S-02 | `PermitRootLogin no` |

`Port` and `AllowUsers` are also enforced from configuration.

The configuration is validated with `sshd -t` before the function returns. If the
resulting file is invalid, `set -e` aborts the script while the daemon is still running
its previous, valid configuration — the administrator keeps their session. A reload on
a broken configuration kills the daemon, and on a remote server without console access
the machine is lost. This is the single most common failure in SSH hardening.

The reload itself is intentionally not performed: the lab statement does not require it.

### Identity domain

| Rule | Implementation |
|---|---|
| I-01 | `minlen`, `ucredit`, `lcredit`, `dcredit`, `ocredit` in `/etc/security/pwquality.conf`; `PASS_MAX_DAYS` in `/etc/login.defs` |
| I-02 | `deny` in `/etc/security/faillock.conf` |
| I-03 | Accounts with `1000 < UID < 65000`, not in `sudo` or `wheel`, removed with `userdel -r` |
| I-04 | `passwd -l root` |

Complexity and expiry live in two different files because they are enforced by two
different mechanisms: `pam_pwquality` evaluates a password at the moment it is changed,
whereas `PASS_MAX_DAYS` is an account property read by `login` and `useradd`.

In `pwquality`, a **negative** credit imposes a minimum for that character class, while
a positive one grants a length bonus. `ucredit = -1` therefore means "at least one
uppercase character, mandatory".

`passwd -l root` prefixes the password hash in `/etc/shadow` with `!`, so no input can
ever produce a matching hash. The account remains reachable through `sudo` and SSH keys:
one authentication method is disabled, the account is not destroyed.

`userdel -r` also removes the home directory. Without `-r`, orphaned files remain owned
by a now-free UID, which will be reassigned to the next account created — silently
granting it access to the previous user's data.

### System domain

| Rule | Implementation |
|---|---|
| H-01 | `apt-get update` and `apt-get upgrade` under `DEBIAN_FRONTEND=noninteractive` |
| H-02 | `apt-get purge` of `telnet`, `ftp`, `netcat-traditional` |
| H-03 | `apt-get install` of `auditd` and `fail2ban` |

`DEBIAN_FRONTEND=noninteractive` prevents `apt` from opening a configuration dialog and
blocking forever. An automation script must never wait for a human — it may be running
under cron or across two hundred machines.

`apt-get` is used rather than `apt`: its output contract is stable across versions,
which `apt`'s explicitly is not.

`purge` rather than `remove`, so configuration files disappear along with the binaries.

---

## 5. Ordering

`harden.sh` calls the domains in this order:

1. **Network** — close what can be closed while access is still guaranteed
2. **SSH** — restrict remote access, validated before anything is reloaded
3. **System** — package operations, which depend on working network access
4. **Identity** — the destructive domain, run last, once everything else has converged

---

## 6. Idempotence

Every configuration directive is written **declaratively**: all existing occurrences of
the key are deleted — including commented-out ones — and the desired line is appended.

```bash
sed -i "/^[[:space:]]*#\?[[:space:]]*${key}[[:space:]=]/d" "$file"
printf '%s%s%s\n' "$key" "$sep" "$value" >> "$file"
```

This collapses the four cases (absent / present and correct / present and wrong /
present but commented) into a single code path.

It also neutralises a trap: `sysctl.conf` gives precedence to the **last** occurrence
of a key, while `sshd_config` gives it to the **first**. Simply appending directives
would silently have no effect on SSH.

The character class `[[:space:]]` is used rather than `\s`: `/etc/login.defs` separates
key and value with a **tab**, and `\s` is a GNU extension unavailable on BSD `sed`.

The firewall rules file is fully regenerated on each run (`>` then `>>`), which makes
idempotence structural rather than something to verify. A manual edit by an
administrator is overwritten — deliberately: the script is the authority.

`mkdir -p`, `touch`, `apt-get install` and `chmod` are naturally idempotent.
`apt-get purge` on an already-absent package is neutralised with `|| true`, since
"the package is not installed" is the desired outcome, not a failure. This is the only
place where `set -e` is bypassed.

---

## 7. Logging

One line per event:

```json
{"timestamp":"2026-08-14T08:24:52Z","component":"framework","target":"/var/log/hardening.log","status":"initialized","details":"Hardening framework initialized"}
```

| Field | Content |
|---|---|
| `timestamp` | UTC, ISO-8601 |
| `component` | Subsystem involved (`framework`, `network`, `sshd`, `identity`) |
| `target` | Object modified. `-` when not applicable |
| `status` | Outcome (`initialized`, `changed`) |
| `details` | Human-readable message |

**UTC and ISO-8601.** Local time is unusable for multi-server correlation, and the
daylight-saving rollback produces a duplicated hour — two distinct events can carry the
same timestamp. ISO-8601 also sorts correctly as plain text.

**Fixed-column schema.** A log is consumed by a parser before a human reads it: a stable
schema can be parsed, a variable one forces the consumer to guess.

**`component` is mandatory** — it has no default value, and the function fails if the
caller omits it. A log line that does not say *who* is speaking is unusable.

**Permissions `600 root:root`.** The log describes the machine's security configuration:
it is a map of the attack surface and must be readable by root only. Permissions are set
once, at initialization.

**Precondition errors go to `stderr`.** The root check runs before `$LOG_FILE` exists
and at a point where writing to `/var/log/` is impossible. You cannot log the error that
prevents logging.

**Two runs produce two log lines**, which does not violate idempotence: that property
applies to convergence targets — configuration files, services, accounts. The log is an
observation artifact; being cumulative is its nature.

---

## 8. Safety guards

**`set -euo pipefail`**, immediately after the shebang:

- `-e`: abort on the first failing command. Without it a script can print several
  errors and still exit successfully, leaving the server half-hardened — more dangerous
  than an unhardened one, because it is believed to be protected.
- `-u`: a forgotten configuration variable becomes a fatal error rather than an empty
  string propagating into a firewall rule.
- `pipefail`: an intermediate failure in a pipeline is no longer masked by the success
  of the last command.

**Root check via `$EUID`**, as a guard clause:

```bash
if [[ "$EUID" -ne 0 ]]; then
    echo "harden.sh: must be run as root." >&2
    exit 1
fi
```

`$EUID` is a shell built-in. `whoami` is an external binary resolved through `PATH`,
therefore substitutable by an attacker who controls the environment. **A security
control never depends on `PATH`.**

**Self-locating script:**

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

Relative `source` paths break as soon as the script is invoked from another directory —
which is exactly how it will be invoked by cron or a configuration management tool.

**No side effect before preconditions are validated.** `init_log()` writes to
`/var/log/`, so it runs only after the root check.

---

## 9. Known limitations

**JSON escaping.** Log fields are interpolated without escaping. A double quote inside
`details` breaks the line. An attacker able to influence a field could forge entries or
make genuine ones unreadable to the SIEM (**CWE-117**). Same root cause as SQL injection
and XSS: mixing data and structure through string concatenation. `printf` with a `%s`
template separates format from data but does not neutralise special characters inside a
value. Planned fix: build the JSON with `jq`.

**Local log only.** Against an attacker who has obtained root, a local log can be
rewritten. The only real defense is shipping entries to a separate machine (rsyslog to a
SIEM), since the lines have already left by the time of compromise. Local mitigation:
`chattr +a`.

**No dry-run mode.** The script has no way to report what it *would* change without
changing it — a standard expectation for configuration management tooling.

---

## 10. Planned improvements

**Permissions `640 root:adm`.** `600 root:root` makes the log unreadable to the
operations team, creating an availability problem for the information itself (*bus
factor*). The `adm` group grants read access without write access.

**Configuration management.** This framework is ad-hoc scripting: it expresses *how*.
Ansible or Puppet express *what* — the desired state — and provide idempotence,
inventory and compliance reporting natively. The declarative write used here is a step
in that direction.

---

## 11. Repository security

No SSH public key is committed. A public key is not a secret in the cryptographic sense,
but publishing it documents the attack surface: which accounts exist, and which machines
reach them.

`config/harden.cfg` contains policy, never secrets — an application of Kerckhoffs's
principle: security must rest on control mechanisms, not on the secrecy of the design.

Moving the SSH port reduces automated scan noise but **is not a security measure**: it
is security through obscurity, and a port scan defeats it in seconds.

# Section to append to README.md — Task 2

## Task 2 — Audit & Verification

A security tool that works silently is dangerous. Auditors need proof, operations
needs visibility. At the end of every run, `harden.sh` writes a human-readable
compliance report to `audit_report.txt`.

### Output location

The report is written to the **current working directory** — the directory the
operator runs the command from — not to the directory where the script is stored:

```bash
RUN_DIR="$PWD"                              # frozen before any cd
REPORT_FILE="$RUN_DIR/audit_report.txt"
```

`$SCRIPT_DIR` (where the script lives) and `$PWD` (where it was launched from) are
two different things. Only `$SCRIPT_DIR` is used to `source` the libraries.

### Two outputs, two audiences

| Output | Format | Reader |
|---|---|---|
| `$LOG_FILE` | JSON, one object per event | machines: SIEM, log shipper |
| `audit_report.txt` | plain text, `[INFO]/[WARN]/[ERROR]` | humans: auditor, operator |

The same reasoning already applied to `harden.cfg` (read by `source`) versus
`firewall.rules` (read by a line parser): one consumer, one format.

### How the information travels

Each hardening function records what it did in three accumulator arrays through
the helpers `report_info`, `report_warn` and `report_error`. A single function,
`generate_report()`, formats them and writes the file. Only one function ever
opens the report, so the format lives in exactly one place.

Package counts come from a `dpkg -s` test performed **before** acting: the script
only reports what actually changed, which is also what makes those functions
idempotent.

### Guaranteed generation: the EXIT trap

```bash
on_exit() {
    local rc=$?
    generate_report "$rc"
    exit "$rc"
}
trap on_exit EXIT
```

With `set -e`, a critical failure kills the script immediately. Without a trap the
report would never be written on failure, and `COMPLIANCE STATUS: FAIL` could
never be printed — the worst case, a half-hardened server, would be the one case
with no evidence.

`EXIT` fires on every exit path: normal end, explicit `exit`, or death caused by
`set -e`. `local rc=$?` must be the first line of the handler, because any other
command would overwrite `$?`. `exit "$rc"` preserves the original exit code, so a
failure is never silently turned into a success.

Note the deliberate limit: the `source` statements run *before* the trap is
installed, so a missing library or config file aborts loudly with no report. A
bootstrap failure is not a compliance failure and must not be dressed up as one.

### Compliance status

`PASS` requires both: an exit code of 0, and an empty `REPORT_ERROR` array.
Any recorded error, even a non-critical one, downgrades the run to `FAIL`.

### Sample output

```
===============================================
 HARDENING AUDIT REPORT - 2026-08-18 14:32:01
===============================================

[INFO] Hardening procedure completed successfully.
[INFO] SSH configured on port 2222.
[INFO] Firewall policy created: /etc/hardening/firewall.rules
[INFO] Installed: auditd, fail2ban.
[INFO] Removed: telnet, ftp, netcat-traditional.
[INFO] 3 unauthorized users removed: guest, temp, test.
[WARN] Package updates skipped (already up to date).

===============================================
 COMPLIANCE STATUS: PASS
===============================================
```

On a second consecutive run the report shows `Installed: none`, `Removed: none`
and `0 unauthorized users removed`. Those lines are not noise: they are the
evidence of idempotence.

### Testing

```bash
bash tests/test_report.sh      # no root, no system change: 15 assertions
shellcheck harden.sh lib/*.sh  # run locally, the lab VM has no shellcheck
```

`tests/test_report.sh` sources `lib/system.sh` to obtain the functions only,
fills the accumulators by hand and asserts on the generated file. It covers the
nominal run, a recorded error, an interrupted script and a no-change second run.
