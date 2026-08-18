# shellcheck shell=bash
# Logging, package management, and audit report generation.

log() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local component="${1:?log: component manquant}"
    local target="${2:-"-"}"
    local status="${3:-"-"}"
    local details="${4:-"-"}"
    printf '{"timestamp":"%s","component":"%s","target":"%s","status":"%s","details":"%s"}\n' \
        "$timestamp" "$component" "$target" "$status" "$details" >> "$LOG_FILE"
}

init_log() {
    touch "$LOG_FILE"
    chown root:root "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

# --- Audit accumulators ----------------------------------------------------
# log() writes the machine-readable journal; the accumulators below feed the
# human-readable report. Two consumers, two formats. Every hardening function
# records what it did here; only generate_report() writes the file.

REPORT_INFO=()
REPORT_WARN=()
REPORT_ERROR=()

report_info()  { REPORT_INFO+=("$1"); }
report_warn()  { REPORT_WARN+=("$1"); }
report_error() { REPORT_ERROR+=("$1"); }

PKGS_INSTALLED=()
PKGS_REMOVED=()

# 1 = repositories reachable, 0 = offline. A package that cannot be downloaded
# is an environment limitation, not a policy breach.
APT_AVAILABLE=1

# --- Package domain --------------------------------------------------------

update_system() {
    export DEBIAN_FRONTEND=noninteractive
    local out

    # An automation script must never block: the same reasoning that motivates
    # DEBIAN_FRONTEND=noninteractive, applied to the network.
    if ! timeout 120 apt-get update -qq \
            -o Acquire::Retries=1 -o Acquire::http::Timeout=15 >/dev/null 2>&1; then
        APT_AVAILABLE=0
        report_warn "Package repositories unreachable: package index not updated."
        log "system" "apt" "failed" "index update failed or timed out"
        return 0
    fi

    # The output is captured, not discarded: it is the only way to tell
    # "upgraded" from "nothing to do", a distinction the report must show.
    out="$(timeout 600 apt-get upgrade -y -qq 2>&1 || true)"
    if [[ -z "$out" ]] || grep -q "0 upgraded, 0 newly installed" <<<"$out"; then
        report_warn "Package updates skipped (already up to date)."
    else
        report_info "System packages upgraded."
    fi

    log "system" "packages" "changed" "Repositories updated and packages upgraded"
}

remove_bloatware() {
    local pkg

    # Testing dpkg -s before acting makes the function idempotent and yields
    # the exact counts the report needs.
    for pkg in telnet ftp netcat-traditional; do
        if dpkg -s "$pkg" &>/dev/null; then
            if apt-get purge -y -qq "$pkg" &>/dev/null; then
                PKGS_REMOVED+=("$pkg")
            else
                report_error "Failed to remove package: $pkg"
            fi
        fi
    done

    log "system" "packages" "changed" "Insecure packages removed"
}

install_security_tools() {
    local pkg

    for pkg in auditd fail2ban; do
        if dpkg -s "$pkg" &>/dev/null; then
            continue
        fi
        if (( APT_AVAILABLE == 0 )); then
            report_warn "$pkg missing and repositories unreachable: install deferred."
            continue
        fi
        if apt-get install -y -qq "$pkg" &>/dev/null; then
            PKGS_INSTALLED+=("$pkg")
        else
            report_error "Failed to install package: $pkg"
        fi
    done

    log "system" "packages" "changed" "Security tools installed"
}

# --- Audit report ----------------------------------------------------------

# "a, b, c" from an array. "${array[*]}" would join on the first character of
# IFS only, dropping the space after each comma.
_join() {
    local out="" item
    for item in "$@"; do
        [[ -n "$out" ]] && out+=", "
        out+="$item"
    done
    printf '%s' "$out"
}


# Called by the EXIT trap, so it runs whether the script succeeded or died.
generate_report() {
    local rc="${1:-0}"
    local now; now="$(date '+%Y-%m-%d %H:%M:%S')"
    local line="==============================================="
    local status="PASS"

    if ((rc != 0)) || ((${#REPORT_ERROR[@]} > 0)); then
        status="FAIL"
    fi


    {
        printf '%s\n' "$line"
        printf ' HARDENING AUDIT REPORT - %s\n' "$now"
        printf '%s\n\n' "$line"

        if [[ "$status" == "PASS" ]]; then
            printf '[INFO] Hardening procedure completed successfully.\n'
        else
            printf '[ERROR] Hardening procedure did not complete cleanly (exit code %s).\n' "$rc"
        fi


        if ((${#PKGS_INSTALLED[@]} > 0)); then
            printf '[INFO] Installed: %s.\n' "$(_join "${PKGS_INSTALLED[@]}")"
        else
            printf '[INFO] Installed: none (required packages already present).\n'
        fi

        if ((${#PKGS_REMOVED[@]} > 0)); then
            printf '[INFO] Removed: %s.\n' "$(_join "${PKGS_REMOVED[@]}")"
        else
            printf '[INFO] Removed: none (no forbidden package found).\n'
        fi

        local entry
        for entry in "${REPORT_INFO[@]}";  do printf '[INFO] %s\n'  "$entry"; done
        for entry in "${REPORT_WARN[@]}";  do printf '[WARN] %s\n'  "$entry"; done
        for entry in "${REPORT_ERROR[@]}"; do printf '[ERROR] %s\n' "$entry"; done

        printf '\n%s\n' "$line"
        printf ' COMPLIANCE STATUS: %s\n' "$status"
        printf '%s\n' "$line"
    } > "$REPORT_FILE"

    chmod 644 "$REPORT_FILE" 2>/dev/null || true
    log "report" "$REPORT_FILE" "written" "status=$status"
}
