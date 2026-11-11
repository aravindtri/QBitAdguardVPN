FROM linuxserver/qbittorrent:latest

# gcompat and libc6-compat are needed for the glibc AdGuard binary on Alpine.
# iproute2 is required to pin the interface MAC before the CLI reads it.
RUN apk add --no-cache \
    curl \
    gcompat \
    libc6-compat \
    tar \
    gzip \
    ca-certificates \
    sed \
    grep \
    gawk \
    dos2unix \
    iproute2

ENV USER=root

# Pin the installer. The release script on HEAD tracks whatever is current.
ARG ADGUARD_VERSION=1.8.2
RUN curl -fsSL "https://raw.githubusercontent.com/AdguardTeam/AdGuardVPNCLI/v${ADGUARD_VERSION}/scripts/release/install.sh" \
    | sh -s -- -v -a y

COPY root/ /

RUN dos2unix \
        /etc/s6-overlay/s6-rc.d/adguardvpn/type \
        /etc/s6-overlay/s6-rc.d/adguardvpn/run \
        /etc/s6-overlay/s6-rc.d/vpn-tun-up/type \
        /etc/s6-overlay/s6-rc.d/vpn-tun-up/up \
        /custom-cont-init.d/01-adguard-setup \
        /usr/local/lib/adguard-persist.sh \
        /usr/local/bin/adguard-login \
    && chmod +x \
        /custom-cont-init.d/* \
        /etc/s6-overlay/s6-rc.d/adguardvpn/run \
        /etc/s6-overlay/s6-rc.d/vpn-tun-up/up \
        /usr/local/lib/adguard-persist.sh \
        /usr/local/bin/adguard-login
