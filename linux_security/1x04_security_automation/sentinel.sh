#!/bin/bash
. sentinel.conf
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
			fi
		fi	
	done
}
check_ports
