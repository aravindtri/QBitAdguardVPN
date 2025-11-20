# qBittorrent with AdGuard VPN

This setup runs qBittorrent behind AdGuard VPN using Docker.
The VPN connection is isolated to the container.

## Prerequisites

- Docker and Docker Compose installed.
- AdGuard VPN account.

## Setup

1.  **Build and Start the Container**
    ```bash
    docker-compose up -d --build
    ```

2.  **Login to AdGuard VPN**
    The first time you run it, the VPN won't connect because you aren't logged in.
    You need to execute the login command inside the container.

    ```bash
    docker exec -it qbittorrent-vpn adguardvpn-cli login
    ```
    Follow the on-screen instructions to login via browser or credentials.

3.  **Connect and Restart**
    After logging in, restart the container to establish the connection and configure qBittorrent.

    ```bash
    docker-compose restart
    ```

4.  **Verify**
    Check the logs to ensure VPN is connected:
    ```bash
    docker logs qbittorrent-vpn
    ```
    You should see "AdGuard VPN: Connecting..." and successful connection messages.

    Open qBittorrent Web UI at `http://localhost:8080`.
    Check `Tools -> Options -> Advanced -> Network Interface`. It should be set to `tun0`.

## Configuration

- **Config Persistence**: AdGuard VPN configuration is stored in `./config/adguardvpn-cli`.
- **Downloads**: Downloads are stored in `./downloads`.
- **Ports**: Web UI is on 8080. Torrent ports are 6881.

## Troubleshooting

- If the container keeps restarting or logs show "Connection failed", ensure you have logged in correctly.
- If qBittorrent doesn't download, check if the VPN is actually connected.
