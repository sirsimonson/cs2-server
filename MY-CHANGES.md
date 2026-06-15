# My Changes vs Upstream

## docker-compose.yml

### Build Context
- **Upstream**: Uses remote Git URL (`https://github.com/ayayrom/CS2-Server-ARM-Docker.git#main`)
- **Mine**: Uses local build context (`.`) for Coolify integration

### Networking
- **Upstream**: Exposes ports (`27015:27015/tcp`, `27015:27015/udp`)
- **Mine**: Uses `network_mode: host` to avoid NAT overhead that causes subtick desync

### Resources
- **Upstream**: No resource limits (uses `ulimits.nice` for CPU scheduling only)
- **Mine**: No Docker resource limits either (respects upstream recommendation)

### Volumes
- **Upstream**: Bind mounts (`./cs2-data`, `./fex-data`)
- **Mine**: Named volumes (`cs2-data`, `fex-data`) - managed by Docker, better for Coolify

### Environment Variables
- **Upstream**: `STEAM_GAMESERVER_API`, `STARTUP_MAP`, `MMS_URL`, `CSS_URL`
- **Mine**: `STEAM_TOKEN` (Coolify variable name), `INSTALL_MODDING`, `CPU_CORE_COUNT`, `TZ` (same EXTRA_PARAMS as upstream now)

## init-server.sh

### SteamCMD Update Handling
- **Upstream**: On failure, nukes entire `game/` and `steamapps/` directories and redownloads
- **Mine**: Retry logic with exponential backoff (5 attempts max)
  - First retry uses normal `+app_update 730`
  - Subsequent retries use `+app_update 730 validate` to recover from corruption
  - Cleans only `downloading` dir and `appinfo.vdf` between retries
  - Preserves game files unless validation is required

This makes the server more resilient to transient SteamCMD failures without destroying existing installation.