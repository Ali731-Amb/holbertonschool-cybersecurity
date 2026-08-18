#!/usr/bin/env bash
# harden.sh — STIG-2024 hardening orchestrator.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The audit report belongs in the directory the operator ran the command from,
# which is not the directory the script is stored in. Frozen before any cd.
RUN_DIR="$PWD"
REPORT_FILE="$RUN_DIR/audit_report.txt"

# system.sh first: it defines log() and init_log(), used by every other domain.
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config/harden.cfg"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/system.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/network.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/ssh.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/identity.sh"

if [[ "$EUID" -ne 0 ]]; then
    printf '[ERROR] This script must be run as root.\n' >&2
    exit 1
fi

init_log

# The EXIT trap fires on every exit path, including a death caused by set -e.
# Without it, a critical failure would leave a half-hardened server and no
# report at all — the one case where evidence matters most.
# $? must be read first: any other command would overwrite it.
# shellcheck disable=SC2329  # invoked indirectly by the trap below
on_exit() {
    local rc=$?
    generate_report "$rc"
    exit "$rc"
}
trap on_exit EXIT

# Network first: the policy file is written while access is still guaranteed.
configure_firewall
harden_kernel

harden_ssh

update_system
remove_bloatware
install_security_tools

# Identity last: account removal is the least reversible operation here.
harden_password_policy
lock_root_account
remove_unauthorized_users

exit 0
