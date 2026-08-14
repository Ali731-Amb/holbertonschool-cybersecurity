# configure le demon sshd : permitRootLoginno, changement de port, white list pour users. 
set_ssh_directive() {
    local key="$1"
    local value="$2"

    sed -i "/^[[:space:]]*#\?[[:space:]]*${key}[[:space:]]/d" "$SSHD_CONFIG"
    echo "${key} ${value}" >> "$SSHD_CONFIG"
}

# In production: systemctl reload sshd
    # Not performed here — the lab statement does not require it,
    # and reloading would terminate the current session if a rule is wrong.s
harden_ssh() {
    set_ssh_directive "Port" "$SSH_PORT"
    set_ssh_directive "PermitRootLogin" "$SSH_PERMIT_ROOT_LOGIN"
    set_ssh_directive "PasswordAuthentication" "no"
    set_ssh_directive "PubkeyAuthentication" "yes"
    set_ssh_directive "AllowUsers" "$ALLOWED_SSH_USERS"

    sshd -t

    log "sshd" "$SSHD_CONFIG" "changed" "SSH daemon hardened"
}
