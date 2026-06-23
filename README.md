# Media Server

Docker Compose stack: **Jellyfin** streams, **Sonarr/Radarr** automate, **Prowlarr** finds (via **FlareSolverr** for Cloudflare-protected indexers), **qBittorrent** downloads (through **Gluetun** VPN). **autoheal** restarts anything unhealthy; a small **notifier** sidecar pushes alerts to your phone via **ntfy.sh**.

## Layout

```
jellyfin/
├── .env                ← secrets + paths (edit before starting)
├── docker-compose.yml  ← all services
├── scripts/
│   └── notifier.sh     ← ntfy.sh watcher for unhealthy containers
├── config/             ← per-app settings (created automatically)
└── data/
    ├── torrents/       ← qBittorrent saves here
    └── media/          ← finished files; Jellyfin reads here
```

`/data` is one shared mount so finished torrents **hardlink** into the media library — instant, no extra disk space.

## Setup

1. **Copy `.env.example` to `.env`** and fill in your VPN's `WIREGUARD_PRIVATE_KEY` and `WIREGUARD_ADDRESSES`. Set `NTFY_TOPIC` to a long random string (e.g. `head -c 12 /dev/urandom | base64 | tr -d '/+='`). Adjust `TZ`, `SERVER_COUNTRIES` (comma-separated for fallback, e.g. `United States,Canada`), `LAN_SUBNET` if needed.
2. **Start:** `docker compose up -d`
3. **Verify VPN** (must show VPN IP, not your home IP):
   ```bash
   docker exec gluetun wget -qO- https://ipinfo.io/ip
   ```
4. **Get qBittorrent temp password:** `docker logs qbittorrent | grep -i password`
5. **Subscribe to push alerts:** install the **ntfy** app on your phone and subscribe to `https://ntfy.sh/<your NTFY_TOPIC>`. You'll get a push whenever any container becomes unhealthy.

### NordVPN WireGuard key

The Manual Setup page only shows OpenVPN credentials. To get the WireGuard key:

1. Generate an access token at [my.nordaccount.com/dashboard/nordvpn/access-tokens](https://my.nordaccount.com/dashboard/nordvpn/access-tokens/).
2. Extract the key:
   ```bash
   curl -s -u token:YOUR_ACCESS_TOKEN https://api.nordvpn.com/v1/users/services/credentials \
     | jq -r .nordlynx_private_key
   ```
   No `jq`? Swap the pipe for:
   ```bash
   | python -c "import sys,json;print(json.load(sys.stdin)['nordlynx_private_key'])"
   ```
3. Revoke the access token after use.

## Configure (in this order)

| App | URL | What to do |
|---|---|---|
| qBittorrent | `:8080` | Set real login. Default save path → `/data/torrents` |
| Prowlarr | `:9696` | **Settings → Indexers → Add Indexer Proxy → FlareSolverr**, host `http://flaresolverr:8191/`, set a tag (e.g. `cf`). Add indexers; tag any Cloudflare-protected ones with `cf`. **Settings → Apps**: add Sonarr (`http://sonarr:8989`) + Radarr (`http://radarr:7878`) with their API keys |
| Sonarr | `:8989` | **Download Clients** → qBittorrent, host **`gluetun`**, port `8080`. **Root Folder** → `/data/media/tv` |
| Radarr | `:7878` | Same as Sonarr but root folder → `/data/media/movies` |
| Jellyfin | `:8096` | First-run wizard. Add libraries from `/data/media/movies` and `/data/media/tv` |

## The one gotcha

When connecting Sonarr/Radarr to qBittorrent, the host is **`gluetun`** (not `qbittorrent`). qBittorrent shares Gluetun's network, so its name doesn't resolve.

## Common issues

- **Torrents stall after a while** → healthcheck auto-restarts qBittorrent. Persistent? Swap image to `lscr.io/linuxserver/qbittorrent:libtorrentv1`.
- **VPN won't connect** → verify WireGuard key/address. Proton keys expire ~yearly.
- **qBittorrent UI dead** → Gluetun is down. `docker logs gluetun`.
- **Indexer test fails with 403 / Cloudflare** → tag it with `cf` so it routes through FlareSolverr (see Prowlarr config above).
- **Container stuck unhealthy** → autoheal restarts it after ~15s; you'll get a ntfy push.

Full walkthrough: `~/Documents/notes/guides/media-server-setup.md`
