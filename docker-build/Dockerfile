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

# The v1.8.2 install.sh still downloads 1.7.12. Fetch the release archive.
ARG ADGUARD_VERSION=1.8.2
RUN set -eu; \
    case "$(uname -m)" in \
      x86_64) asset="linux-x86_64" ;; \
      aarch64) asset="linux-aarch64" ;; \
      armv7l) asset="linux-armv7" ;; \
      *) echo "unsupported arch: $(uname -m)"; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/adguard.tgz \
      "https://github.com/AdguardTeam/AdGuardVPNCLI/releases/download/v${ADGUARD_VERSION}/adguardvpn-cli-${ADGUARD_VERSION}-${asset}.tar.gz"; \
    mkdir -p /opt/adguardvpn_cli; \
    tar -xzf /tmp/adguard.tgz -C /opt/adguardvpn_cli --strip-components=1; \
    ln -sf /opt/adguardvpn_cli/adguardvpn-cli /usr/local/bin/adguardvpn-cli; \
    rm -f /tmp/adguard.tgz; \
    adguardvpn-cli --version

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
