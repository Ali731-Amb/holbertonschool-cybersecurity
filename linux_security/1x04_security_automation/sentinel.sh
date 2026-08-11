#!/bin/bash
. sentinel.conf; check_services() { for svc in "${SERVICES[@]}"; do if pgrep -f "$svc" >/dev/null; then echo "OK: $svc is running"; else eval "$svc" && echo "FIXED: Restarted $svc" || echo "ERROR: Failed to start $svc"; fi; done; }; check_services
