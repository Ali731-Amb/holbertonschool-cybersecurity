# 2x03 — Traffic Forensics: "The Breach"

## Scenario

A company has been breached. The incident response team hands over a single piece of evidence: `incident.pcap`. Clicking through it in Wireshark would take hours and could not be repeated on the next capture.

The analyst builds a set of **one-line `tshark` scripts**, each answering one forensic question, so the whole investigation becomes automated, reproducible and reusable on any capture passed as an argument (`$1`). Step by step, the scripts rebuild the full attack: reconnaissance, initial access, takeover, command and control, and data exfiltration.

## Learning Objectives

- Why `tshark` complements Wireshark: explore with the GUI, automate with the command line
- The role of each option: `-r` (read), `-Y` (select packets), `-T fields -e` (select columns), `-q -z` (statistics)
- Detect anomalies against a baseline: unexpected protocol, unusual ratio, port that does not match its content
- Chain `tshark` with `sort`, `uniq -c`, `sort -rn`, `wc -l` to rank and count
- Recognize each phase of an attack in network traffic
- Extract transferred files and prove their identity with a hash
- Understand what encryption hides and what it does not

## Requirements

- Tested on Kali Linux
- `tshark` installed (non-root capture allowed through the `wireshark` group)
- Every script is a single command line taking the capture file as `"$1"`

## Investigation Steps

### Overview

- **Protocol hierarchy** (`-q -z io,phs`): where to look, and what does not fit the baseline.
- **Top talkers** (`-T fields -e ip.src | sort | uniq -c | sort -rn`): which hosts dominate the traffic.
- **Conversations** (`-q -z conv,tcp`): who talks to whom, and how much.

### Reconnaissance

- **Port scan**: connection attempts only, `SYN` without `ACK` (the server's `SYN/ACK` also has `SYN` set), counted per source.
- **Directory enumeration**: bursts of HTTP `404` responses (`http.response.code == 404`).
- **Tooling**: User-Agents of offensive tools (Nmap, Nikto, DirBuster, gobuster, sqlmap).

### Initial access

- **Injected parameters** extracted from HTTP requests, decoded from hexadecimal.
- **SQL injection** patterns in request URIs, matched case-insensitively (`matches "(?i)..."`).
- **Credential stuffing**: a login page requested dozens of times.
- **Keyword search** in whole packets (`frame contains`).

### Takeover and persistence

- **Reverse shell**: the victim connects **out** to the attacker (port 4444) and sends back the output of the commands.
- **Beacon**: the compromised machine contacts its command and control server at a regular interval.
- **Large outbound payloads** isolated by size.

### Exfiltration

- Transferred files extracted from the HTTP stream and fingerprinted with `md5sum`, to prove which file left the network.

### Timeline

All attacker events, with timestamps, rebuilt into the kill chain:

```
scan → enumeration → initial access → reverse shell → C2 beacon → exfiltration
```

## Security Notes

- **Always quote filters** in the shell: unquoted `&&` chains commands, unquoted `>` creates a file.
- A filter is written **field, operator, value**; a field alone only tests that the field exists.
- **Egress filtering** (only 80/443 out) blocks a reverse shell on 4444, until the attacker switches to 443: content and behavior must be inspected, not just ports.
- **TLS hides the content, not the behavior**: IPs, timing, sizes and intervals still reveal a beacon.
- Only state what the evidence proves.

## Author

**Alison Amblard** — Holberton School, Cybersecurity
GitHub: [Ali731-Amb](https://github.com/Ali731-Amb)
