# Media Server

Docker Compose stack: **Jellyfin** streams, **Sonarr/Radarr** automate, **Prowlarr** finds, **qBittorrent** downloads (through **Gluetun** VPN).

## Layout

```
jellyfin/
├── .env                ← secrets + paths (edit before starting)
├── docker-compose.yml  ← all services
├── config/             ← per-app settings (created automatically)
└── data/
    ├── torrents/       ← qBittorrent saves here
    └── media/          ← finished files; Jellyfin reads here
```

`/data` is one shared mount so finished torrents **hardlink** into the media library — instant, no extra disk space.

## Setup

1. **Edit `.env`** — fill in your VPN's `WIREGUARD_PRIVATE_KEY` and `WIREGUARD_ADDRESSES`. Adjust `TZ`, `SERVER_COUNTRIES`, `LAN_SUBNET` if needed.
2. **Start:** `docker compose up -d`
3. **Verify VPN** (must show VPN IP, not your home IP):
   ```bash
   docker exec gluetun wget -qO- https://ipinfo.io/ip
   ```
4. **Get qBittorrent temp password:** `docker logs qbittorrent | grep -i password`

## Configure (in this order)

| App | URL | What to do |
|---|---|---|
| qBittorrent | `:8080` | Set real login. Default save path → `/data/torrents` |
| Prowlarr | `:9696` | Add indexers. **Settings → Apps**: add Sonarr (`http://sonarr:8989`) + Radarr (`http://radarr:7878`) with their API keys |
| Sonarr | `:8989` | **Download Clients** → qBittorrent, host **`gluetun`**, port `8080`. **Root Folder** → `/data/media/tv` |
| Radarr | `:7878` | Same as Sonarr but root folder → `/data/media/movies` |
| Jellyfin | `:8096` | First-run wizard. Add libraries from `/data/media/movies` and `/data/media/tv` |

## The one gotcha

When connecting Sonarr/Radarr to qBittorrent, the host is **`gluetun`** (not `qbittorrent`). qBittorrent shares Gluetun's network, so its name doesn't resolve.

## Common issues

- **Torrents stall after a while** → healthcheck auto-restarts qBittorrent. Persistent? Swap image to `lscr.io/linuxserver/qbittorrent:libtorrentv1`.
- **VPN won't connect** → verify WireGuard key/address. Proton keys expire ~yearly.
- **qBittorrent UI dead** → Gluetun is down. `docker logs gluetun`.

Full walkthrough: `~/Documents/notes/guides/media-server-setup.md`
