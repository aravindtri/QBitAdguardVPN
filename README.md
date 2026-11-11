# qBittorrent with AdGuard VPN

qBittorrent in Docker, with AdGuard VPN isolated to the container.

## Prerequisites

- Docker and Docker Compose.
- An AdGuard VPN account.

## Setup

1. Build and start:

    ```bash
    docker compose up -d --build
    ```

2. Log in once. Use the helper. It stops the VPN service first so a second CLI process cannot clear the login.

    ```bash
    docker exec -it qbittorrent-vpn adguard-login
    ```

    The CLI prints a browser link. Finish that login in the browser.

3. The service connects on its own after login. To force it:

    ```bash
    docker compose restart
    ```

4. Check the logs. You want a connected message, not exit code 11.

    ```bash
    docker logs qbittorrent-vpn
    docker exec qbittorrent-vpn adguardvpn-cli status
    ```

    Web UI: `http://localhost:8080`. It stays down until `tun0` exists.  
    `Tools -> Options -> Advanced -> Network Interface` should be `tun0`.

5. Copy the saved MAC into `docker-compose.yml` so a recreate keeps the same identity:

    ```yaml
    mac_address: "PASTE_FROM_config/adguardvpn-identity/mac"
    ```

    Then `docker compose up -d --force-recreate`.

## Why login survives a restart

AdGuard VPN CLI encrypts the profile with the container Ethernet MAC. A new MAC makes `status` say you are not logged in (exit 11). `config` and `status` can also overwrite the saved profile when that MAC does not match. Two CLI processes at once can clear the login too.

The old startup script ran `adguardvpn-cli config set-mode` on every boot, before the identity was pinned, and from a different home directory than `docker exec`.

On startup the image now:

- stores the CLI profile in `./config/adguardvpn-cli`
- points root and the linuxserver user at that same directory
- saves the interface MAC in `./config/adguardvpn-identity/mac` and puts it back before any CLI command
- skips the CLI entirely when the MAC cannot be restored, so a bad start cannot wipe the profile
- waits for `tun0` before starting qBittorrent

If a previous restart already wiped the profile, run `adguard-login` once after rebuilding. Later restarts reuse that login.

To always use one country, uncomment `VPN_LOCATION` in `docker-compose.yml` (`NL`, `US`, a city name). Unset, the CLI reuses the last location.

Do not delete `./config/adguardvpn-identity/mac` unless you are ready to log in again.

## Configuration

- Config and login: `./config/adguardvpn-cli`
- Saved MAC: `./config/adguardvpn-identity/mac`
- Downloads: `./downloads`
- Web UI: `8080`
- Torrent port: `6881` is published, but qBittorrent is bound to `tun0`, so peers do not come back through that host port

## Troubleshooting

- Exit code 11 after a rebuild means the saved profile was wiped, or the running MAC does not match `adguardvpn-identity/mac`. Set `mac_address`, recreate, then run `adguard-login` once. Do not run `adguardvpn-cli config` until `status` shows you are logged in.
- The first start copies an existing profile to `./config/adguardvpn-identity/profile-backup` before the CLI can overwrite it.
- Do not run `docker exec qbittorrent-vpn adguardvpn-cli login` while the service is retrying. Use `adguard-login`.
- If downloads stall, confirm the VPN is connected and qBittorrent is bound to `tun0`.
- Temporary WebUI password (PowerShell):

    ```powershell
    docker logs qbittorrent-vpn 2>&1 `
        | Select-String "A temporary password is provided for this session" `
        | Select-Object -Last 1
    ```

- Temporary WebUI password (bash):

    ```bash
    docker logs qbittorrent-vpn 2>&1 \
      | grep "A temporary password is provided for this session" \
      | tail -n 1
    ```
