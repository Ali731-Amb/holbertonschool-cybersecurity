# 2x04 — Perimeter Control: "The Lockdown"

> *"The perimeter is dead. Long live the perimeter."*

## Scenario

After a breach where attackers compromised a printer and moved laterally to database servers, ACME Corp deploys a new **Secure Gateway Server** (`acme-gw01`). It must become the only entry point to the sensitive network segments.

The mission is to turn a fresh Ubuntu 22.04 server into an **Iron Bastion**, with three layers of defense:

| Layer | Goal | Tool |
|---|---|---|
| **Filtering** | Drop everything by default, allow only what is justified | `nftables` |
| **Tunneling** | Take SSH off the public internet, reachable only through an encrypted tunnel | `WireGuard` |
| **Routing** | Let the bastion act as a gateway for VPN clients | IP forwarding + NAT |

Requirements from the client:

- Block **all** incoming connections by default
- Allow SSH **only** through the VPN
- Act as a **NAT gateway** for VPN clients
- **Survive a reboot** without losing configuration
- Never lock yourself out: no rollback plan, no change

## Learning Objectives

**Stateful firewalling**
- How connection tracking works (`ct state`)
- The difference between `NEW`, `ESTABLISHED` and `RELATED`
- Why *default deny* is the foundation of secure firewalling
- How to order rules for performance (most-matched first)

**VPN deployment**
- How WireGuard's cryptokey routing works
- The relationship between private keys, public keys and `AllowedIPs`
- How to configure server and client endpoints
- Why WireGuard is silent to port scanners

**Kernel routing**
- What `ip_forward` does and why it is disabled by default
- The difference between routing and NAT
- How masquerading rewrites source addresses, and why return traffic needs it

**Operational safety**
- The *panic button* pattern for remote firewall changes
- How to make rules persistent across reboots
- How to bind services to specific interfaces
- How to verify that firewall rules actually work

## Environment

| Item | Value |
|---|---|
| Target | `acme-gw01`, Ubuntu 22.04, provisioned with **Multipass** + `cloud-init.yaml` |
| User | `engineer` |
| Firewall | `nftables` |
| VPN | `wireguard`, `wireguard-tools` |
| Network tools | `ss`, `ip`, `ping` |
| System tools | `systemctl`, `sysctl`, `at` |

### Workflow

1. Write scripts and configuration files locally.
2. Copy them to the target with `scp`.
3. Run them remotely over `ssh` (or `multipass shell acme-gw01`).
4. **Always arm the panic button before applying firewall rules.**

> Windows host note: Multipass runs on Hyper-V. A WSL2 distribution sits on a separate virtual network and cannot reach the VM directly, so deployment scripts are run from a shell on the Windows side (Git Bash). VPN tools that create `/32` interfaces (e.g. Tailscale) can prevent the Multipass service from starting.

## Tasks

### 0. The Baseline — `0-audit.sh`

Lists every listening TCP and UDP socket with its owning process.

```bash
ss -tulnp
```

Run with `sudo`: without privileges, the kernel hides which process owns root sockets and the report looks complete while it is not. `-n` keeps raw port numbers instead of names guessed from `/etc/services`.

### 1. The Tooling — `1-install.sh`

Installs `nftables`, `wireguard` and `wireguard-tools` non-interactively, then **enables** nftables without starting it (starting it with no rules could lock us out).

```bash
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install nftables wireguard wireguard-tools && systemctl enable nftables
```

### 2. The Panic Button — `2-panic.sh`

A *Dead Man's Switch*: flushes all rules, rebuilds a table with three `ACCEPT` chains, and reschedules itself in 5 minutes with `at`. If a bad rule locks us out, access comes back automatically.

- `at` hands the job to the `atd` daemon, so it survives the death of the SSH session (unlike a background `sleep`).
- Commands are chained with `;` so the reschedule happens even if one step fails.
- The script path is absolute.
- Jobs started with `sudo` belong to root: check and cancel them with `sudo atq` / `sudo atrm <n>`.

### 3. The Skeleton — `skeleton.conf`

Defines the `inet filter` table (IPv4 + IPv6 with a single rule set) and three chains:

| Chain | Traffic | Policy |
|---|---|---|
| `input` | destined to the server | `drop` |
| `forward` | passing through the server | `drop` |
| `output` | leaving the server | `accept` |

The policy is the default verdict, applied only when no rule matched.

### 4. The State Machine — `skeleton.conf`

```
ct state established,related accept
```

Placed first in `input`: replies to known connections pass immediately, which is also the most-matched rule. `new` is never accepted here, otherwise default deny would be cancelled.

### 5. Critical Services — `skeleton.conf`

```
iifname "lo" accept
tcp dport 22 accept
ip protocol icmp accept
ip6 nexthdr icmpv6 accept
```

Loopback, SSH and ping. ICMPv6 is required for IPv6 neighbor discovery.

### 6. Deployment & Verification — `6-deploy.sh`

Runs locally: copies the configuration and the panic script to the target, arms the panic button, applies the rules and lists the active ruleset. Chained with `&&`: if the safety net cannot be armed, nothing is applied.

```bash
scp skeleton.conf 2-panic.sh engineer@<target>:~ && ssh engineer@<target> "sudo /home/engineer/2-panic.sh && sudo nft -f /home/engineer/skeleton.conf && sudo nft list ruleset"
```

Cancelling the reset is a **human decision**, taken only after a **new** SSH connection succeeds.

### 7. Key Generation — `7-keygen.sh`

Generates the server and client keypairs locally, with private files created in mode `600`.

```bash
umask 077 && wg genkey | tee server_private | wg pubkey > server_public && wg genkey | tee client_private | wg pubkey > client_public
```

Key files are excluded from the repository (`.gitignore`).

### 8. Server Configuration — `wg0.conf`

`[Interface]` with address `10.200.0.1/24`, port `51820` and the server private key; one `[Peer]` with the client public key and `AllowedIPs = 10.200.0.2/32`. `AllowedIPs` is both a routing directive and an access control: a peer can only use the addresses bound to its key.

### 9. Client Configuration — `client.conf`

Same structure, plus an `Endpoint` (server IP and port): the client must know where to call, while the server learns the client address from authenticated packets.

### 10. Firewall Opening — `skeleton.conf`

```
udp dport 51820 accept
```

Opening the port exposes nothing visible: WireGuard never answers packets from unknown keys, so to a scanner the port looks closed or filtered.

### 11. The Handshake — `11-verify.sh`

Prints the time of the last handshake with each peer, the proof that the tunnel is up.

```bash
wg show wg0 latest-handshakes
```

### 12. Kernel Forwarding — `12-forward.sh`

Enables IP forwarding immediately (`sysctl -w`) and persistently (`/etc/sysctl.conf`).

### 13. Forwarding Rules — `skeleton.conf`

```
iifname "wg0" accept
```

`ip_forward` builds the corridor; the `forward` chain guards it. Two independent locks: only traffic coming from the tunnel may cross.

### 14. NAT Masquerade — `skeleton.conf`

```
table ip nat {
        chain postrouting {
                type nat hook postrouting priority 100;
                masquerade
        }
}
```

The bastion rewrites the source address of VPN client traffic with its own, so that replies find their way back.

### 15. SSH Restriction — `skeleton.conf`

```
ip saddr 10.200.0.2 tcp dport 22 accept
```

SSH now only accepts the VPN client. Verified from both sides: SSH to the public address fails, SSH to `10.200.0.1` through the tunnel succeeds.

## Security Notes

- **Never apply firewall rules without an armed rollback.**
- Check a rule file before applying it: `sudo nft -c -f skeleton.conf`.
- A rule that is listed is not a rule that is proven: always test the real effect.
- `nft -f` only loads rules in memory. For persistence, the rules must be in `/etc/nftables.conf`, loaded at boot by the enabled `nftables` service.
- Private keys never leave the machine they belong to and never go into Git.

## Author

**Alison Amblard** — Holberton School, Cybersecurity
GitHub: [Ali731-Amb](https://github.com/Ali731-Amb)
