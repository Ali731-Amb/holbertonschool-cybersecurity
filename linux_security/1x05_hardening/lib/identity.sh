# shellcheck shell=bash
# Generic idempotent directive setter.
# $1 = file, $2 = key, $3 = value, $4 = separator (e.g. " " or " = ")
set_directive() {
    local file="$1"
    local key="$2"
    local value="$3"
    local sep="$4"

    touch "$file"
    sed -i "/^[[:space:]]*#\?[[:space:]]*${key}[[:space:]=]/d" "$file"
    printf '%s%s%s\n' "$key" "$sep" "$value" >> "$file"
}

harden_password_policy() {
    # I-01 — complexity, enforced by pam_pwquality at password change time
    set_directive "$PWQUALITY_FILE" "minlen"  "$PASS_MIN_LEN" " = "
    set_directive "$PWQUALITY_FILE" "ucredit" "-1" " = "
    set_directive "$PWQUALITY_FILE" "lcredit" "-1" " = "
    set_directive "$PWQUALITY_FILE" "dcredit" "-1" " = "
    set_directive "$PWQUALITY_FILE" "ocredit" "-1" " = "

    # I-01 — password ageing, read by login/useradd
    set_directive "$LOGIN_DEFS" "PASS_MAX_DAYS" "$PASS_MAX_DAYS" "   "

    # I-02 — account lockout after repeated failures
    set_directive "$FAILLOCK_FILE" "deny" "$FAIL_LOCK_ATTEMPTS" " = "

    log "identity" "$PWQUALITY_FILE" "changed" "Password policy enforced"
}

lock_root_account() {
    # I-04 — disable password-based root authentication.
    # The account stays usable through sudo; only the password is locked.
    passwd -l root >/dev/null

    log "identity" "root" "changed" "Root password locked"
}

remove_unauthorized_users() {
    # I-03 — remove non-administrative human accounts.
    local user uid groups
    local -a candidates=() removed=()

    # The list is built before any deletion: userdel rewrites /etc/passwd,
    # which this loop is reading.
    while IFS=: read -r user _ uid _; do
        (( uid > 1000 && uid < 65000 )) || continue
        [[ "$user" == "${SUDO_USER:-}" ]] && continue

        groups="$(id -nG "$user" 2>/dev/null || true)"
        if grep -qwE 'sudo|wheel|adm' <<<"$groups"; then
            log "identity" "$user" "skipped" "administrative account"
            continue
        fi

        candidates+=("$user")
    done < /etc/passwd

    for user in "${candidates[@]}"; do
        if userdel -r "$user" &>/dev/null; then
            removed+=("$user")
            log "identity" "$user" "changed" "Account removed"
        else
            # Non-critical: reported, but hardening continues.
            report_error "Failed to remove user: $user"
            log "identity" "$user" "failed" "userdel returned an error"
        fi
    done

    if (( ${#removed[@]} > 0 )); then
        report_info "${#removed[@]} unauthorized users removed: $(_join "${removed[@]}")."
    else
        report_info "0 unauthorized users removed."
    fi
}
