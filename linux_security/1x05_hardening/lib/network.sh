# shellcheck shell=bash
#ignorer les redirection ICMP, deactiver le routage ip, activer la protection anti spoonfing, controle réseau qui ne passe pas par le firewall
configure_firewall() {
    mkdir -p "$(dirname "$FIREWALL_RULES")"

    {
        echo "DEFAULT_INPUT=deny"
        echo "DEFAULT_OUTPUT=allow"
        echo "ALLOW_TCP=$SSH_PORT"
    } > "$FIREWALL_RULES"

    if [[ "$ALLOW_HTTP" == "true" ]]; then
        echo "ALLOW_TCP=80" >> "$FIREWALL_RULES"
    fi

    if [[ "$ALLOW_HTTPS" == "true" ]]; then
        echo "ALLOW_TCP=443" >> "$FIREWALL_RULES"
    fi

    chmod 600 "$FIREWALL_RULES"

    log "network" "$FIREWALL_RULES" "changed" "Firewall policy written"
}

set_sysctl_param() {
    local key="$1"
    local value="$2"

    sed -i "/^[[:space:]]*#\?[[:space:]]*${key//./\\.}[[:space:]]*=/d" "$SYSCTL_FILE"
    echo "${key}=${value}" >> "$SYSCTL_FILE"
}

harden_kernel() {
	touch "$SYSCTL_FILE"
    set_sysctl_param net.ipv4.ip_forward "0" 
	set_sysctl_param net.ipv4.conf.all.accept_redirects "0"
	set_sysctl_param net.ipv4.icmp_echo_ignore_all "1"
    log "network" "$SYSCTL_FILE" "changed" "Kernel parameters hardened"
}
