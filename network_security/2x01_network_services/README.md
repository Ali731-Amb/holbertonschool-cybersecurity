# 2x01 — Network Services: "The Lost Emails"

## Scenario

Emails are disappearing, users cannot reach some services, and nobody knows whether the problem comes from the network configuration or from the naming infrastructure. Before anything can be fixed, the auditor needs a **diagnostic toolbox**: a set of small, reliable scripts that answer one precise question each about **DHCP** (how a machine gets its network configuration) and **DNS** (how a name becomes an address).

Each tool is a building block of a real audit: identify the resolver, find the DHCP server, follow a name through the DNS hierarchy, map the mail servers, read the zone metadata, and check whether the zone leaks.

## Learning Objectives

- How a machine obtains its configuration through DHCP (**DORA**: Discover, Offer, Request, Acknowledge)
- Why a rogue DHCP server is a man-in-the-middle position, and how to defend against it
- How DNS resolution works: recursive resolver, iterative queries, root → TLD → authoritative servers
- The role of TTL and caching, and why `/etc/hosts` bypasses DNS
- What each record type reveals during reconnaissance: `A`, `CNAME`, `MX`, `TXT`, `NS`, `SOA`, `PTR`
- Why an open zone transfer (`AXFR`) is a critical exposure
- How cache poisoning works and what DNSSEC protects

## Requirements

- Scripts tested on Kali Linux / Ubuntu
- Every script has exactly **2 lines**: `#!/bin/bash` and a single command line
- All files end with a newline and are executable
- Main tool: `dig`

## Tasks

### 0. The Resolver — `0-resolver.sh`

Prints the IP address of the primary DNS resolver.

```bash
grep -m1 "^nameserver" /etc/resolv.conf | awk '{print $2}'
```

### 1. The DHCP Server — `1-dhcp.sh`

Finds the DHCP Server Identifier. Depending on the system, the information lives in different places (`/var/lib/dhcp` lease files, `/var/log/syslog`, `nmcli`, `journalctl`), so the script tries several sources in fallback with `||` and hides errors with `2>/dev/null`.

### 2. The Hosts File — `2-hosts.sh`

Prints the IPv4 address mapped to `localhost` in `/etc/hosts`, filtering by **name** (not by IP) and excluding IPv6 entries.

```bash
grep -w "localhost" /etc/hosts | grep -v ":" | head -n1 | awk '{print $1}'
```

Security angle: an entry in `/etc/hosts` overrides DNS, which is why malware tampers with it.

### 3. The Address — `3-address.sh`

Returns the `A` record (IPv4) of a domain.

```bash
dig +short "$1" | grep -m1 "^[0-9]"
```

### 4. The Alias — `4-cname.sh`

Returns the `CNAME` (alias) of a domain.

```bash
dig +short "$1" CNAME
```

### 5. The Mail Servers — `5-mx.sh`

Lists the `MX` records sorted by priority (lowest value = preferred server).

```bash
dig +short "$1" MX | sort -n
```

In an audit, MX records show who handles the mail: the first target of a phishing campaign.

### 6. The Text Records — `6-txt.sh`

Returns the `TXT` records (SPF policy, domain verifications…).

```bash
dig +short "$1" TXT
```

### 7. The Root — `7-root.sh`

Follows the full resolution with `+trace` and extracts the first root server consulted.

```bash
dig +trace "$1" | grep -m1 "Received.*root-servers" | awk '{print $6}' | cut -d'#' -f1
```

### 8. The Reverse — `8-reverse.sh`

Reverse DNS lookup: from an IP back to a name (`PTR`, zone `in-addr.arpa`).

```bash
dig +short -x "$1"
```

A PTR record is declared by the owner of the IP, so it can be forged.

### 9. The Authority — `9-soa.sh`

Returns the primary name server from the `SOA` record.

```bash
dig +short "$1" SOA | awk '{print $1}'
```

The SOA also exposes the admin email and a serial number that reveals how often the zone changes.

### 10. Direct Query

Queries a specific DNS server with the `@server` syntax, bypassing the local resolver: useful to audit an internal DNS, compare answers between servers, or detect a lying resolver.

### 11. Zone Transfer

Requests a full zone transfer (`AXFR`). An open AXFR hands out the complete map of the zone, internal subdomains included. Defense: restrict transfers to secondary servers (`allow-transfer`) and authenticate them (TSIG). Legal practice target: `zonetransfer.me`.

## Security Notes

- An attack happens at the layer of the mapping it forges: a lying DNS is layer 7, ARP spoofing is layer 2.
- **Rogue DHCP** → defended by DHCP snooping and 802.1X.
- **Cache poisoning** affects every client of a shared resolver for the whole TTL → defended by DNSSEC.
- DNS is also used as a covert channel (C2, exfiltration), often through `TXT` records, because it passes most firewalls.

## Author

**Alison Amblard** — Holberton School, Cybersecurity
GitHub: [Ali731-Amb](https://github.com/Ali731-Amb)
