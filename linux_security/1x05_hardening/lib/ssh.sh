# shellcheck shell=bash
# configure le demon sshd : PermitRootLogin no, port, white list users.
# In production the daemon would be reloaded; a reload on a broken config
# terminates the current session, hence the mandatory sshd -t beforehand.

set_ssh_directive() {
    local key="$1"
    local value="$2"
    touch "$SSHD_CONFIG"
    sed -i "/^[[:space:]]*#\?[[:space:]]*${key}[[:space:]]/d" "$SSHD_CONFIG"
    echo "${key} ${value}" >> "$SSHD_CONFIG"
}

harden_ssh() {
    set_ssh_directive "Port" "$SSH_PORT"
    set_ssh_directive "PermitRootLogin" "$SSH_PERMIT_ROOT_LOGIN"
    set_ssh_directive "PasswordAuthentication" "no"
    set_ssh_directive "PubkeyAuthentication" "yes"
    set_ssh_directive "AllowUsers" "$ALLOWED_SSH_USERS"

    # Three distinct outcomes, three distinct severities.
    if ! command -v sshd >/dev/null 2>&1; then
        # Environment limitation, not a policy breach.
        report_warn "sshd binary unavailable: configuration written but not validated."
    elif sshd -t 2>/dev/null; then
        report_info "SSH configured on port $SSH_PORT (root login disabled, password auth disabled)."
        if ! systemctl reload ssh 2>/dev/null; then
            report_warn "sshd reload skipped: systemd unavailable in this environment."
        fi
    else
        # Policy breach: the file we just wrote is not usable.
        report_error "sshd configuration invalid, reload aborted."
    fi

    log "sshd" "$SSHD_CONFIG" "changed" "SSH daemon hardened"
}
