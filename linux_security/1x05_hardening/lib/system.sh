# service inutile déactivé, permissions sur fichiers sensible, banniere légale, modules noyau bloqués. 
#pas de chemin ou valeur en dur 


log() {
	local timestamp
	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ") #format date + heure
	local component="${1:?log: component manquant}"
    local target="${2:-"-"}"
    local status="${3:-"-"}"
    local details="${4:-"-"}"
	printf '{"timestamp":"%s","component":"%s","target":"%s","status":"%s","details":"%s"}\n' \
        "$timestamp" "$component" "$target" "$status" "$details" >> "$LOG_FILE"
}

init_log (){
	touch "$LOG_FILE"
	chown root:root "$LOG_FILE"
	chmod 600 "$LOG_FILE"
}

update_system() {
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq
    apt-get upgrade -y -qq

    log "system" "packages" "changed" "Repositories updated and packages upgraded"
}

remove_bloatware() {
    apt-get purge -y -qq telnet ftp netcat-traditional || true

    log "system" "packages" "changed" "Insecure packages removed"
}

install_security_tools() {
    apt-get install -y -qq auditd fail2ban

    log "system" "packages" "changed" "Security tools installed"
}
