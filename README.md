# qBittorrent with AdGuard VPN

qBittorrent in Docker, with AdGuard VPN isolated to the container.

Torrent traffic is bound to `tun0`. If the tunnel is down, qBittorrent does not fall back to the host network. The Web UI can still be up.

## Prerequisites

- Docker and Docker Compose.
- An AdGuard VPN account.
- `/dev/net/tun` on the host. The compose file mounts it. If it is missing, create it before the first start:

    ```bash
    sudo mkdir -p /dev/net
    sudo mknod /dev/net/tun c 10 200
    sudo chmod 666 /dev/net/tun
    ```

    That node can disappear on reboot if udev does not recreate it. Put the same commands in a boot script if the container then fails to start.

## Setup

1. Build and start:

    ```bash
    docker compose up -d --build
    ```

2. Log in once, from a terminal. The helper needs a TTY. It stops the VPN service first so a second CLI process cannot clear the login.

    ```bash
    docker exec -it qbittorrent-vpn adguard-login
    ```

    Open the browser link the CLI prints. Wait until it says you are logged in. That only means the account is saved. The tunnel comes up a few seconds later, when the service starts again.

    Do not run `adguardvpn-cli login` yourself while the service is retrying.

3. Confirm the tunnel, not just the login text:

    ```bash
    docker exec qbittorrent-vpn ls /sys/class/net
    ```

    `tun0` should be in that list. A restart is not required after a normal login.

4. Save the container MAC before the next rebuild. AdGuard encrypts the login to that MAC. `docker compose up --build` recreates the container and assigns a new one.

    ```bash
    docker exec qbittorrent-vpn cat /sys/class/net/eth0/address
    ```

    Put that value in `docker-compose.yml`:

    ```yaml
    mac_address: "PASTE_THE_ADDRESS"
    ```

    The same value is stored in `./config/adguardvpn-identity/mac`. Do not delete that file unless you are ready to log in again.

## Check that qBittorrent is on the VPN

1. Web UI: `Tools -> Options -> Advanced -> Network Interface` is `tun0`.

2. The torrent port is listening on `tun0` only:

    ```bash
    docker exec qbittorrent-vpn ss -lntu | grep 6881
    ```

    You want `6881` on a `tun0` address. It must not be listening on `eth0`. Port `8080` is the Web UI and is supposed to be reachable on the LAN.

3. The container's public IP is not the host's public IP:

    ```bash
    wget -qO- https://api.ipify.org; echo
    docker exec qbittorrent-vpn wget -qO- https://api.ipify.org; echo
    ```

Do not run `adguardvpn-cli status` or `adguardvpn-cli config` while the VPN service is running. A second CLI process can drop the login. Use the `tun0` and IP checks above.

## Web UI password

The image prints a one-session password. A later qBittorrent restart prints a new one. The older line in the log no longer works. Use the last line only.

PowerShell:

```powershell
docker logs qbittorrent-vpn 2>&1 |
  Select-String "temporary password" |
  Select-Object -Last 1
```

bash:

```bash
docker logs qbittorrent-vpn 2>&1 |
  grep "temporary password" |
  tail -n 1
```

Username is `admin` until you change it. Set your own password in the Web UI after the first login.

Web UI: `http://localhost:8080`

## Why login survives a restart

AdGuard VPN CLI encrypts the profile with the container Ethernet MAC. A new MAC makes the CLI say you are not logged in (exit 11). `config` and `status` can also overwrite the saved profile when that MAC does not match.

On startup the image:

- stores the CLI profile in `./config/adguardvpn-cli`
- points root and the linuxserver user at that same directory
- saves the interface MAC in `./config/adguardvpn-identity/mac` and puts it back before any CLI command
- skips the CLI when the MAC cannot be restored, so a bad start cannot wipe the profile
- binds qBittorrent to `tun0`

A `docker compose restart` keeps the MAC. A recreate without `mac_address` does not. If a recreate already wiped the profile, run `adguard-login` once more.

To always use one country, uncomment `VPN_LOCATION` in `docker-compose.yml` (`NL`, `US`, or a city name). Unset, the CLI reuses the last location.

## Configuration

- Config and login: `./config/adguardvpn-cli`
- Saved MAC: `./config/adguardvpn-identity/mac`
- Downloads: `./downloads`
- Web UI: `8080`
- Torrent port: `6881` is published, but qBittorrent is bound to `tun0`, so peers do not come back through that host port

## Troubleshooting

- Exit code 11 after a rebuild means the saved profile was wiped, or the running MAC does not match `adguardvpn-identity/mac`. Set `mac_address`, recreate, then run `adguard-login` once.
- The first start copies an existing profile to `./config/adguardvpn-identity/profile-backup` before the CLI can overwrite it.
- Compose fails on `/dev/net/tun`: create the device node in Prerequisites, then start again.
- `flock: unrecognized option: w` means the container is running an old `adguard-login`. Rebuild the image.
- If downloads stall, confirm `tun0` exists and port `6881` is bound to it.
