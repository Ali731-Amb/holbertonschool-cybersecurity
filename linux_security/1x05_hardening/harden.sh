#!/bin/bash
set -euo pipefail
#controle root
if [[ "$EUID" -ne 0 ]]; then
	echo "harden.sh: doit être exécuté en tant que root." >&2
	exit 1
fi

# Chargement de la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config/harden.cfg"
source "$SCRIPT_DIR/lib/system.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/ssh.sh"
source "$SCRIPT_DIR/lib/identity.sh"

# Initialisation du fichier de log
init_log

log "framework" "$LOG_FILE" "initialized" "Hardening framework initialized"

configure_firewall
harden_kernel
update_system
remove_bloatware
install_security_tools
harden_password_policy
lock_root_account
remove_unauthorized_users
