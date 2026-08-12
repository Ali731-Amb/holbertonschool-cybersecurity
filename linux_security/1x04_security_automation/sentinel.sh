#!/bin/bash
. sentinel.conf
[ -n "$SERVICES" ] && [ -n "$FILES_TO_WATCH" ] || { echo "Error: config file is missing" >&2; exit 1; }

# ============ Task 4 : JSON logger ============
log() {
	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	echo "{\"timestamp\": \"$timestamp\", \"component\": \"$1\", \"target\": \"$2\", \"status\": \"$3\", \"details\": \"$4\"}" >> /var/log/sentinel.log
}

# ============ Task 1 : check_services ============
check_services() {
	for svc in "${SERVICES[@]}"; do
		if pgrep -f "$svc" >/dev/null; then
			echo "OK: $svc is running"
			log SERVICE "$svc" OK "Service is running"
		else
			if eval "$svc"; then
				echo "FIXED: Restarted $svc"
				log SERVICE "$svc" FIXED "Restarted service"
			else
				echo "ERROR: Failed to start $svc"
				log SERVICE "$svc" ALERT "Failed to reload"
			fi
		fi
	done
}

# ============ Task 2 : check_integrity ============
check_integrity() {
	for file in "${FILES_TO_WATCH[@]}"; do
		gold="/var/backups/sentinel/$(basename "$file").gold"
		hash1=$(md5sum "$file" | awk '{print $1}')
		hash2=$(md5sum "$gold" | awk '{print $1}')
		if [ "$hash1" = "$hash2" ]; then
			echo "OK: $file integrity verified"
			log INTEGRITY "$file" OK "Integrity verified"
		else
			cp "$gold" "$file"; echo "FIXED: Restored $file"
			log INTEGRITY "$file" FIXED "Restored file"
		fi
	done
}

# ============ Task 3 : check_ports ============
check_ports() {
	for port in $(ss -lntH | awk '{print $4}' | awk -F: '{print $NF}'); do
		found=0
		for allowed in "${ALLOWED_PORTS[@]}"; do
			if [ "$port" = "$allowed" ]; then
				found=1
			fi
		done
		if [ "$found" = 0 ]; then
			pid=$(ss -lntpH | grep ":$port " | grep -oP 'pid=\K[0-9]+')
			if [ -n "$pid" ]; then
				kill -9 "$pid"
				echo "ALERT: Killed rogue process on port $port"
				log PORT "$port" ALERT "Killed rogue process"
			fi
		fi
	done
}

# ============ main ============
check_services
check_integrity
check_ports
