#!/usr/bin/env bash
# tests/test_report.sh — teste generate_report() SANS root et SANS toucher au système.
#
# Principe : on source lib/system.sh pour n'obtenir que les fonctions, on
# remplit les accumulateurs à la main, et on vérifie le fichier produit.
# C'est le seul morceau de la tâche 2 qui soit testable hors VM — d'où
# l'intérêt d'avoir isolé la mise en forme dans une fonction dédiée.
#
# Usage : bash tests/test_report.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export LOG_FILE="$TMP/harden.log"
export REPORT_FILE="$TMP/audit_report.txt"
SSH_PORT=2222
FIREWALL_RULES="/etc/hardening/firewall.rules"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/system.sh"

PASS=0; FAIL=0
check() {
    local label="$1" pattern="$2"
    if grep -qF -- "$pattern" "$REPORT_FILE"; then
        printf '  [OK]   %s\n' "$label"; ((PASS++))
    else
        printf '  [FAIL] %s (attendu : %s)\n' "$label" "$pattern"; ((FAIL++))
    fi
}

# --- Cas 1 : exécution nominale --------------------------------------------
printf '\nCas 1 — exécution réussie\n'
PKGS_INSTALLED=(auditd fail2ban)
PKGS_REMOVED=(telnet ftp netcat-traditional)
report_warn "Package updates skipped (already up to date)."
report_info "3 unauthorized users removed: guest, temp, test."
generate_report 0

check "en-tête présent"        "HARDENING AUDIT REPORT"
check "port SSH"               "[INFO] SSH configured on port 2222."
check "fichier pare-feu"       "[INFO] Firewall policy created: /etc/hardening/firewall.rules"
check "paquets installés"      "[INFO] Installed: auditd, fail2ban."
check "paquets supprimés"      "[INFO] Removed: telnet, ftp, netcat-traditional."
check "comptes supprimés"      "[INFO] 3 unauthorized users removed: guest, temp, test."
check "niveau WARN"            "[WARN] Package updates skipped"
check "statut PASS"            "COMPLIANCE STATUS: PASS"

# --- Cas 2 : une erreur enregistrée -> FAIL --------------------------------
printf '\nCas 2 — une erreur non critique enregistrée\n'
REPORT_INFO=(); REPORT_WARN=(); REPORT_ERROR=()
PKGS_INSTALLED=(); PKGS_REMOVED=()
report_error "Failed to install package: fail2ban"
generate_report 0
check "niveau ERROR"           "[ERROR] Failed to install package: fail2ban"
check "statut FAIL"            "COMPLIANCE STATUS: FAIL"

# --- Cas 3 : mort du script (code != 0) -> FAIL ----------------------------
printf '\nCas 3 — script interrompu (exit 1)\n'
REPORT_INFO=(); REPORT_WARN=(); REPORT_ERROR=()
generate_report 1
check "échec signalé"          "did not complete cleanly (exit code 1)"
check "statut FAIL"            "COMPLIANCE STATUS: FAIL"

# --- Cas 4 : rien à faire (2e passage) -> idempotence ----------------------
printf '\nCas 4 — deuxième passage, aucun changement\n'
REPORT_INFO=(); REPORT_WARN=(); REPORT_ERROR=()
PKGS_INSTALLED=(); PKGS_REMOVED=()
generate_report 0
check "aucune installation"    "[INFO] Installed: none"
check "aucune suppression"     "[INFO] Removed: none"
check "statut PASS"            "COMPLIANCE STATUS: PASS"

printf '\n-------------------------\n'
printf ' %d réussis, %d échoués\n' "$PASS" "$FAIL"
printf -- '-------------------------\n'
(( FAIL == 0 ))
