#!/bin/bash
# Shared setup for AdGuard VPN CLI persistence.
#
# The CLI encrypts its profile to the container Ethernet MAC. A new MAC makes
# status/config report "not logged in" and can overwrite the saved profile
# (AdGuardVPNCLI issue 198). `docker exec` uses HOME=/root, while the s6
# service may see HOME=/config. Both homes must point at the same store.
# Do not call the CLI until the MAC matches. Do not put helper files inside
# the CLI data directory.

adguard_store() {
    printf '%s\n' "/config/adguardvpn-cli"
}

adguard_identity_dir() {
    printf '%s\n' "/config/adguardvpn-identity"
}

adguard_prepare() {
    export HOME=/root
    unset XDG_DATA_HOME
    unset XDG_CONFIG_HOME

    local store identity
    store="$(adguard_store)"
    identity="$(adguard_identity_dir)"
    mkdir -p "$store" "$identity" /root/.local/share /root/.config /config/.local/share /config/.config

    adguard_migrate_dir /root/.local/share/adguardvpn-cli "$store"
    adguard_migrate_dir /root/.config/adguardvpn-cli "$store"
    adguard_migrate_dir /config/.local/share/adguardvpn-cli "$store"
    adguard_migrate_dir /config/.config/adguardvpn-cli "$store"

    ln -sfn "$store" /root/.local/share/adguardvpn-cli
    ln -sfn "$store" /root/.config/adguardvpn-cli
    ln -sfn "$store" /config/.local/share/adguardvpn-cli
    ln -sfn "$store" /config/.config/adguardvpn-cli

    if id abc >/dev/null 2>&1; then
        local abc_home
        abc_home="$(getent passwd abc 2>/dev/null | cut -d: -f6 || true)"
        if [ -n "$abc_home" ] && [ "$abc_home" != "/config" ] && [ "$abc_home" != "/root" ]; then
            mkdir -p "$abc_home/.local/share" "$abc_home/.config"
            ln -sfn "$store" "$abc_home/.local/share/adguardvpn-cli"
            ln -sfn "$store" "$abc_home/.config/adguardvpn-cli"
        fi
    fi

    if [ -n "${VPN_HOSTNAME:-}" ]; then
        hostname "$VPN_HOSTNAME" 2>/dev/null || true
    fi

    adguard_pin_mac || true
    adguard_backup_profile
    return 0
}

# Keep one copy of an existing profile before the CLI can touch it.
# config/status overwrite the encrypted file when the MAC does not match.
adguard_backup_profile() {
    local dest store
    dest="$(adguard_identity_dir)/profile-backup"
    store="$(adguard_store)"
    if [ -d "$dest" ]; then
        return 0
    fi
    if [ -z "$(ls -A "$store" 2>/dev/null)" ]; then
        return 0
    fi
    mkdir -p "$dest"
    cp -a "$store"/. "$dest"/ 2>/dev/null || true
    echo "AdGuard VPN: backed up the existing profile to $dest"
}

adguard_migrate_dir() {
    local src="$1"
    local store="$2"
    if [ -d "$src" ] && [ ! -L "$src" ]; then
        if [ -z "$(ls -A "$store" 2>/dev/null)" ]; then
            mv "$src"/* "$store"/ 2>/dev/null || true
        fi
        rm -rf "$src"
    fi
}

adguard_iface() {
    if [ -d /sys/class/net/eth0 ]; then
        printf '%s\n' eth0
        return 0
    fi
    local name
    for name in /sys/class/net/*; do
        name="$(basename "$name")"
        case "$name" in
            lo|tun*|docker*|br-*|veth*) continue ;;
        esac
        printf '%s\n' "$name"
        return 0
    done
    return 1
}

adguard_pin_mac() {
    local iface current saved idfile
    iface="$(adguard_iface)" || {
        echo "AdGuard VPN: no ethernet interface found; cannot pin MAC"
        return 1
    }
    idfile="$(adguard_identity_dir)/mac"
    current="$(tr 'A-Z' 'a-z' < "/sys/class/net/$iface/address")"
    if [ ! -s "$idfile" ]; then
        printf '%s\n' "$current" > "$idfile"
        echo "AdGuard VPN: saved $iface MAC $current"
        return 0
    fi

    saved="$(tr -d '[:space:]' < "$idfile" | tr 'A-Z' 'a-z')"
    if [ "$current" = "$saved" ]; then
        return 0
    fi

    echo "AdGuard VPN: pinning $iface MAC $current -> $saved"
    if ip link set "$iface" address "$saved" 2>/dev/null; then
        return 0
    fi

    local cidr gw cidrs
    cidrs="$(ip -o addr show dev "$iface" 2>/dev/null | awk '{print $4}')" || true
    gw="$(ip -4 route show default 2>/dev/null | awk '{print $3; exit}')" || true
    ip link set "$iface" down || return 1
    if ! ip link set "$iface" address "$saved"; then
        ip link set "$iface" up || true
        return 1
    fi
    ip link set "$iface" up || return 1
    for cidr in $cidrs; do
        ip addr replace "$cidr" dev "$iface" || return 1
    done
    if [ -n "$gw" ]; then
        ip route replace default via "$gw" dev "$iface" || true
        ping -c 1 -W 1 "$gw" >/dev/null 2>&1 || true
    fi

    current="$(tr 'A-Z' 'a-z' < "/sys/class/net/$iface/address")"
    [ "$current" = "$saved" ]
}

adguard_identity_ready() {
    local iface current saved idfile
    iface="$(adguard_iface)" || return 1
    idfile="$(adguard_identity_dir)/mac"
    [ -s "$idfile" ] || return 1
    current="$(tr 'A-Z' 'a-z' < "/sys/class/net/$iface/address")"
    saved="$(tr -d '[:space:]' < "$idfile" | tr 'A-Z' 'a-z')"
    [ "$current" = "$saved" ]
}

# BusyBox flock has no -w. Retry a non-blocking lock instead.
adguard_lock_wait() {
    local fd="$1"
    local tries="${2:-30}"
    local i=0
    while ! flock -n "$fd"; do
        i=$((i + 1))
        if [ "$i" -ge "$tries" ]; then
            return 1
        fi
        sleep 1
    done
}

# Prints CLI status. Returns 1 when the profile is logged out.
# Caller must already have pinned the MAC. This command can wipe a profile
# when the MAC does not match.
adguard_logged_in() {
    local status
    status="$(adguardvpn-cli status 2>&1 || true)"
    printf '%s\n' "$status"
    if [ -z "$status" ]; then
        return 1
    fi
    if printf '%s\n' "$status" | grep -E -i -q 'please log in|must log in|not logged in|you are not logged in'; then
        return 1
    fi
    return 0
}
