# 2x02 — The Wiretap

## Scenario

A network has been compromised and a packet capture, `nexus_capture.pcap`, is the only witness. The analyst must read it like an investigator: get the big picture first, then narrow down to the hosts, protocols and sessions that do not belong, recover what was hidden or transmitted in clear text, and rebuild the timeline of the intrusion.

In the second part of the project, the analyst moves from **reading** captures to **producing** them: live capture on a lab network with `tcpdump`, and active reconnaissance with `nmap`, to understand both sides of the wire.

## Learning Objectives

- Read a capture with Wireshark: packet list, details and bytes panes
- Use the Statistics views to get a map before the details: capture properties, protocol hierarchy, conversations, endpoints
- Write display filters (field, operator, value) and combine them with `&&`, `||`, `!`
- Understand what headers reveal: TTL and OS fingerprinting, TCP flags, the three-way handshake, ISN
- Recognize clear-text protocols (Telnet, FTP, SNMP v1/v2c) and the credentials they expose
- Spot covert channels: data hidden in ICMP payloads, DNS used for C2 and exfiltration, suspicious TLS SNI
- Tell a capture filter (BPF, before writing, irreversible) from a display filter (after, reversible)
- Read and run scans with `nmap`, and recognize their signature in a capture
- Rebuild an attack timeline in UTC

## Requirements

- Wireshark (GUI exploration), `tcpdump` (capture), `nmap` (scanning)
- Answers and flags stored in text files, display filters provided as proof
- Bash scripts of exactly 2 lines (`#!/bin/bash` + one command)
- Live capture tasks run on the provided lab environment

## Investigation Steps

### Navigation fundamentals

- **Capture properties**: format (`pcap` vs `pcapng`), number of packets, duration.
- **Packet inspection**: decoding the data field of an ICMP echo request from hexadecimal to ASCII to recover hidden content.
- **IPv4 header**: reading the TTL of a given packet; a TTL above the usual initial values (64 Linux, 128 Windows, 255 network devices) betrays a forged packet.
- **Conversations vs Endpoints**: pairs of hosts vs single hosts with their totals, to find the central machine of the capture.
- **Display filters**: `ip.addr`, `ip.src`, `tcp.port`, `tcp.dstport`, combined with logical operators. Pitfall: `tcp.port != 22` still matches SSH traffic; use `!(tcp.port == 22)`.
- **Protocol hierarchy**: spotting the protocol that should not be there (a single malformed SNMP packet carrying extra data).

### Transport layer

- **TCP handshake**: first successful `SYN` to a web server and its raw Initial Sequence Number (Wireshark shows relative numbers by default).
- **TCP flags**: `tcp.flags.syn`, `.ack`, `.reset`, `.fin`; the host sending the most `RST` packets.
- **UDP**: no handshake, so scans are slow and ambiguous (`open|filtered`).

### Application layer

- **DNS**: queries only (`dns.flags.response == 0`), a malicious domain used for command and control, data carried in a `TXT` answer.
- **HTTP**: a suspicious `POST` and the host behind it.
- **TLS**: the Server Name Indication stays visible in clear text, revealing an exfiltration domain.
- **Telnet**: an illegitimate session, credentials recovered with *Follow TCP Stream*, followed by post-exploitation reconnaissance (`whoami`, `id`, `uname -a`). Typing rhythm (one byte per packet at a perfectly regular interval) shows a scripted login.
- **FTP**: `USER` and `PASS` commands in clear text.

### Live capture

- **`tcpdump` with a BPF filter** on the lab: ICMP to the gateway and HTTP to the web server, after finding the right interface and gateway with `ip -br a` and `ip route`.
- Capture filters are irreversible: capturing `port 80` loses HTTPS forever.

### Active reconnaissance

| Option | Technique |
|---|---|
| `-sn` | host discovery, no port scan |
| `-PR` | ARP discovery (local segment only) |
| `-PM` | ICMP address mask request |
| `-sT` | full TCP connect scan |
| `-sS` | SYN (half-open) scan |
| `-sU` | UDP scan |
| `-sV` | service and version detection |

### Timeline

Reading a SYN scan in the capture (the attacker answers `SYN/ACK` with `RST`: open ports), then the shift from scanning to the Telnet intrusion. Times are always reported in **UTC**.

## Security Notes

- Clear-text protocols (Telnet, FTP, SNMP v1/v2c with the default `public` community) hand credentials to anyone on the path: replace them with SSH, SFTP, SNMPv3.
- Encryption hides the content, not the metadata: IPs, timing, volumes and the TLS SNI remain visible.
- DNS and ICMP are common covert channels because they pass most firewalls.
- Only state what the capture proves.

## Author

**Alison Amblard** — Holberton School, Cybersecurity
GitHub: [Ali731-Amb](https://github.com/Ali731-Amb)
