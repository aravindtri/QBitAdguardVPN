FROM linuxserver/qbittorrent:latest

# Install dependencies for AdGuard VPN CLI
# gcompat and libc6-compat are needed for glibc binary on Alpine
RUN apk add --no-cache \
    curl \
    gcompat \
    libc6-compat \
    tar \
    gzip \
    ca-certificates \
    sed \
    grep \
    dos2unix

# Set USER environment variable for the install script
ENV USER=root

# Install AdGuard VPN CLI
RUN curl -fsSL https://raw.githubusercontent.com/AdguardTeam/AdGuardVPNCLI/HEAD/scripts/release/install.sh | sh -s -- -v -a y

# Copy init script and service files
COPY root/ /

# Fix line endings and permissions
RUN dos2unix /etc/s6-overlay/s6-rc.d/adguardvpn/type && \
    dos2unix /etc/s6-overlay/s6-rc.d/adguardvpn/run && \
    dos2unix /custom-cont-init.d/01-adguard-setup && \
    chmod +x /custom-cont-init.d/* && \
    chmod +x /etc/s6-overlay/s6-rc.d/adguardvpn/run
