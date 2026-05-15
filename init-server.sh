#!/bin/bash

function get_latest_release_asset_url() {
  local repo="$1"
  local asset_pattern="$2"
  local response

  if ! response="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null)"; then
    echo "WARNING: Could not fetch latest release metadata for ${repo} (network error or API rate limit)." >&2
    echo ""
    return 0
  fi

  printf '%s' "$response" | python3 - "$asset_pattern" <<'PY'
import json
import re
import sys

pattern = re.compile(sys.argv[1], re.IGNORECASE)
try:
    payload = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.stderr.write("WARNING: Failed to parse GitHub releases payload for latest asset lookup. Returning empty result; fallback URL will be attempted if configured by caller.\n")
    print("")
    raise SystemExit(0)

for asset in payload.get("assets", []):
    url = asset.get("browser_download_url", "")
    if pattern.search(url):
        print(url)
        raise SystemExit(0)

print("")
PY
}

function download_and_extract() {
  local url="$1"
  local extract_target="$2"
  local temp_file

  if [ -z "$url" ]; then
    return 1
  fi

  temp_file="$(mktemp)"
  if ! curl -fsSL "$url" -o "$temp_file"; then
    rm -f "$temp_file"
    return 1
  fi

  if [[ "$url" == *.zip ]]; then
    unzip -o -q "$temp_file" -d "$extract_target"
  elif [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
    tar zxf "$temp_file" -C "$extract_target"
  else
    rm -f "$temp_file"
    return 1
  fi

  rm -f "$temp_file"
  return 0
}

function ensure_server_cfg_setting() {
  local cfg_path="/cs2-data/game/csgo/cfg/server.cfg"
  local key="$1"
  local value="$2"
  local line="${key} ${value}"

  mkdir -p "$(dirname "$cfg_path")"
  touch "$cfg_path"

  if grep -Eq "^[[:space:]]*${key}[[:space:]]+" "$cfg_path"; then
    sed -i -E "s|^[[:space:]]*${key}[[:space:]]+.*|${line}|g" "$cfg_path"
  else
    printf '%s\n' "$line" >> "$cfg_path"
  fi
}

function installServer() {
  # Add '-beta experimental' before 'validate' if you want to play on the experimental branch (check if CSS has updated the branch first!!!)
  FEXBash './steamcmd.sh +@sSteamCmdForcePlatformBitness 64 +force_install_dir "/cs2-data" +login anonymous +app_update 730 validate +quit'
}

function installModding() {
  # Fallback URLs in case API retrieval fails or is rate-limited
  local fallback_mms_url="https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1383-linux.tar.gz"
  local fallback_css_url="https://github.com/roflmuffin/CounterStrikeSharp/releases/download/v1.0.359/counterstrikesharp-with-runtime-linux-1.0.359.zip"
  local mms_url css_url

  mms_url="${MMS_URL_OVERRIDE:-$(get_latest_release_asset_url "alliedmodders/metamod-source" "mmsource-.*linux.*\\.(tar\\.gz|tgz)$")}"
  css_url="${CSS_URL_OVERRIDE:-$(get_latest_release_asset_url "roflmuffin/CounterStrikeSharp" "counterstrikesharp-with-runtime-linux-.*\\.zip$")}"

  [ -z "$mms_url" ] && mms_url="$fallback_mms_url"
  [ -z "$css_url" ] && css_url="$fallback_css_url"

  if [ ! -f "/cs2-data/game/csgo/addons/metamod.vdf" ]; then
    echo "Downloading Metamod"
    mkdir -p /cs2-data/game/csgo/addons
    if ! download_and_extract "$mms_url" "/cs2-data/game/csgo/"; then
      echo "Failed to download latest Metamod from $mms_url, trying fallback"
      download_and_extract "$fallback_mms_url" "/cs2-data/game/csgo/" || {
        echo "ERROR: Failed to install Metamod"
        exit 1
      }
    fi
  else
    echo "Metamod found, skipping download."
  fi

  if [ ! -f "/cs2-data/game/csgo/addons/counterstrikesharp/bin/linuxsteamrt64/counterstrikesharp.so" ]; then
    echo "Downloading CounterStrikeSharp"
    if ! download_and_extract "$css_url" "/cs2-data/game/csgo/"; then
      echo "Failed to download latest CounterStrikeSharp from $css_url, trying fallback"
      download_and_extract "$fallback_css_url" "/cs2-data/game/csgo/" || {
        echo "ERROR: Failed to install CounterStrikeSharp"
        exit 1
      }
    fi
  else
    echo "CounterStrikeSharp found, skipping download."
  fi

  if grep -q "Game_LowViolence" "/cs2-data/game/csgo/gameinfo.gi"; then
    if ! grep -q "addons/metamod" "/cs2-data/game/csgo/gameinfo.gi"; then
      echo "Patching gameinfo.gi"
      # lol idk if i should keep this or find a different way
      sed -i '/Game_LowViolence/a \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ Game\tcsgo/addons/metamod' "/cs2-data/game/csgo/gameinfo.gi"
    fi
  else
    echo "Cannot find Game_LowViolence"
  fi
}

function install_plugin_from_release() {
  local plugin_name="$1"
  local repo="$2"
  local asset_regex="$3"
  local fallback_url="$4"
  local plugin_marker="$5"
  local plugin_url

  if [ -n "$plugin_marker" ] && [ -e "$plugin_marker" ]; then
    echo "${plugin_name} found, skipping download."
    return 0
  fi

  plugin_url="$(get_latest_release_asset_url "$repo" "$asset_regex")"
  if [ -z "$plugin_url" ]; then
    plugin_url="$fallback_url"
  fi

  if [ -z "$plugin_url" ]; then
    echo "No release asset URL found for ${plugin_name} (${repo}), skipping."
    return 0
  fi

  echo "Installing ${plugin_name} from ${plugin_url}"
  if ! download_and_extract "$plugin_url" "/cs2-data/game/csgo/"; then
    echo "WARNING: Failed to install ${plugin_name} from ${plugin_url}, skipping."
  fi
}

function installPlugins() {
  local plugins_enabled="${INSTALL_PLUGIN_PACK:-true}"
  if [ "$plugins_enabled" != "true" ]; then
    echo "Plugin pack installation disabled (INSTALL_PLUGIN_PACK=${plugins_enabled})."
    return
  fi

  install_plugin_from_release \
    "K4-Zenith" \
    "hoan111/K4-Zenith" \
    "(zenith|k4).*(linux)?.*\\.zip$" \
    "${ZENITH_URL_OVERRIDE}" \
    "/cs2-data/game/csgo/addons/counterstrikesharp/plugins/K4-Zenith/K4-Zenith.dll"

  install_plugin_from_release \
    "CS2_SimpleRanks" \
    "K4ryuu/CS2_SimpleRanks" \
    "simpleranks.*\\.zip$" \
    "${SIMPLERANKS_URL_OVERRIDE}" \
    "/cs2-data/game/csgo/addons/counterstrikesharp/plugins/CS2_SimpleRanks/CS2_SimpleRanks.dll"

  install_plugin_from_release \
    "cs2-quake-sounds" \
    "Kandru/cs2-quake-sounds" \
    "(quake|sound).*(cs2)?.*\\.zip$" \
    "${QUAKESOUNDS_URL_OVERRIDE}" \
    "/cs2-data/game/csgo/addons/counterstrikesharp/plugins/cs2-quake-sounds/cs2-quake-sounds.dll"

  install_plugin_from_release \
    "CS2-Deathmatch" \
    "NockyCZ/CS2-Deathmatch" \
    "(deathmatch|cs2[-_]?deathmatch).*(linux)?.*\\.zip$" \
    "${DEATHMATCH_URL_OVERRIDE}" \
    "/cs2-data/game/csgo/addons/counterstrikesharp/plugins/CS2-Deathmatch/CS2-Deathmatch.dll"
}

function ensure_server_tuning() {
  ensure_server_cfg_setting "sv_parallel_sends" "1"
  ensure_server_cfg_setting "sv_threaded_init" "1"
  ensure_server_cfg_setting "sv_maxunlag" "0.2"
}

function ensure_sqlite_for_rank_plugins() {
  local config_root="/cs2-data/game/csgo/addons/counterstrikesharp/configs/plugins"
  [ -d "$config_root" ] || return 0

  python3 - "$config_root" <<'PY'
import json
import os
import re
import sys

root = sys.argv[1]
targets = []
for current_root, _, files in os.walk(root):
    if re.search(r"(ranks|zenith)", current_root, re.IGNORECASE):
        for filename in files:
            if filename.lower().endswith(".json"):
                targets.append(os.path.join(current_root, filename))

if not targets:
    raise SystemExit(0)

def patch_node(node):
    changed = False
    if isinstance(node, dict):
        for k, v in list(node.items()):
            kl = str(k).lower()
            if isinstance(v, str):
                vl = v.lower()
                if kl in {"dbtype", "databasetype", "storage", "storagetype", "provider"} and vl in {"mysql", "postgres", "postgresql", "mariadb"}:
                    node[k] = "SQLite"
                    changed = True
                # Handles common DSN styles used by rank plugins (e.g. MySQL/PostgreSQL host/server style connection strings).
                elif "connectionstring" in kl and any(word in vl for word in ("server=", "host=", "port=", "uid=", "user id=", "password=", "database=")):
                    node[k] = "Data Source=/cs2-data/game/csgo/addons/counterstrikesharp/data/ranks.db"
                    changed = True
            child_changed = patch_node(v)
            changed = changed or child_changed
    elif isinstance(node, list):
        for item in node:
            changed = patch_node(item) or changed
    return changed

for path in targets:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        continue
    original = json.dumps(data, ensure_ascii=False)
    if patch_node(data):
        updated = json.dumps(data, ensure_ascii=False)
        if original != updated:
            sys.stderr.write(f"INFO: Updated database configuration to SQLite in {path}\n")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
PY
}

function ensure_deathmatch_headshot_only() {
  local dm_config="/cs2-data/game/csgo/addons/counterstrikesharp/configs/plugins/CS2-Deathmatch/CS2-Deathmatch.json"
  mkdir -p "$(dirname "$dm_config")"
  python3 - "$dm_config" <<'PY'
import json
import os
import sys

path = sys.argv[1]
data = {}
if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        data = {}

if not isinstance(data, dict):
    data = {}

only_hs = data.get("Only Headshot")
if not isinstance(only_hs, dict):
    only_hs = {}

only_hs["Enabled"] = True
commands = only_hs.get("Commands")
if isinstance(commands, list):
    merged = []
    for cmd in commands + ["!hs", "!onlyhs"]:
        if isinstance(cmd, str) and cmd not in merged:
            merged.append(cmd)
    only_hs["Commands"] = merged
else:
    only_hs["Commands"] = ["!hs", "!onlyhs"]

data["Only Headshot"] = only_hs

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
}

function main() {
  rm -f /tmp/*FEXServer.Socket*

  if [ ! -d "/home/steam/.fex-emu/RootFS/Ubuntu_22_04" ]; then
    echo "RootFS not found. Cleaning RootFS and running FEXRootFSFetcher."
    mkdir -p /home/steam/.fex-emu/RootFS

    # Clean up potential stale/corrupted downloads
    rm -f /home/steam/.fex-emu/RootFS/*.sqsh

    echo "9" | FEXRootFSFetcher -y -x # should be ubuntu 22.04
  else
    echo "FEX RootFS detected. Skipping download."
  fi

  # Fix for steamclient.so not being found
  mkdir -p /home/steam/.steam/sdk64
  ln -sfn /home/steam/Steam/linux64/steamclient.so /home/steam/.steam/sdk64/steamclient.so

  cd /home/steam/Steam

  # Check if we have proper read/write permissions to /cs2-data
  if [ ! -r "/cs2-data" ] || [ ! -w "/cs2-data" ]; then
    echo 'ERROR: I do not have read/write permissions to /cs2-data! Please run "sudo chown -R 1000:1000 cs2-data/" on host machine, then try again.'
    exit 1
  fi

  # FEX cache system doesn't work right now, maybe enabled in future
  # same permission check for ~/.cache
  #if [ ! -r "/home/steam/.cache/fex-emu" ] || [ ! -w "/home/steam/.cache/fex-emu" ]; then
  #  echo 'ERROR: I do not have read/write permissions to ~/.cache/fex-emu! Please run "sudo chown -R 1000:1000 fex-cache/" on host machine, then try again.'
  #  #exit 1
  #fi

  # legacy, replaced by RootFS check above
  # same permission check for ~/.local/share/fex-emu/Config.json
  #if [ ! -r "/home/steam/.fex-emu/Config.json" ]; then
  #  echo 'WARNING: I cannot read ~/.fex-emu/Config.json! Please run "sudo chown -R 1000:1000 fex-config/" on host machine.'
  #fi

  # Check for SteamCMD updates
  echo 'Checking for SteamCMD updates...'
  FEXBash './steamcmd.sh +quit'

  # Check if the server is installed
  if [ ! -f "/cs2-data/game/bin/linuxsteamrt64/cs2" ]; then
    echo 'Server not found! Installing...'
    installServer
  fi

  # If auto updates are enabled, try updating
  if [ "$ALWAYS_UPDATE_ON_START" == "true" ]; then
    echo 'Checking for updates...'
    installServer
  fi

  if [ "$INSTALL_MODDING" == "true" ]; then
    echo 'Installing mods...'
    installModding
    installPlugins
    ensure_sqlite_for_rank_plugins
    ensure_deathmatch_headshot_only
  fi

  ensure_server_tuning

  echo 'Starting server...'

  cd /cs2-data
  # fix for cs2 not able to find linuxsteamrt64
  export LD_LIBRARY_PATH="/cs2-data/game/bin/linuxsteamrt64:$LD_LIBRARY_PATH"

  # priority leak fix
  pkill -9 FEXServer || true
  # Start server
  export CORES=$CPU_CORE_COUNT

  # nice makes the server of high importance, higher is more important and lower is less important
  # taskset dedicates specific cores to the emulator, else the docker container will default to using all cores
  if [ -z "$STEAM_GAMESERVER_API" ]; then
    echo "WARNING: STEAM_GAMESERVER_API is empty!"
    exec nice -n -10 taskset -c 0-$((CORES-1)) FEXBash "./game/bin/linuxsteamrt64/cs2 -dedicated -usercon -threads $((CORES)) $EXTRA_PARAMS"
  else
    echo "Starting server with all features..."
    exec nice -n -10 taskset -c 0-$((CORES-1)) FEXBash "./game/bin/linuxsteamrt64/cs2 -dedicated -usercon +sv_setsteamaccount $STEAM_GAMESERVER_API -threads $((CORES)) $EXTRA_PARAMS"
  fi
}

main
