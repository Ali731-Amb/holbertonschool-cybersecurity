#!/bin/bash
set -euo pipefail
#controle root
if [[ "$EUID" -ne 0 ]]; then
	echo "harden.sh: doit être exécuté en tant que root." >&2
	exit 1
fi

# Chargement de la configuration
source config/harden.cfg
# Chargement des bibliothèques
source lib/system.sh
source lib/network.sh
source lib/ssh.sh
source lib/identity.sh

# Initialisation du fichier de log
init_log

log "framework" "$LOG_FILE" "initialized" "Hardening framework initialized"
