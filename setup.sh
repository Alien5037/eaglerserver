#!/usr/bin/env bash
# One-time setup. Runs automatically when the Codespace is created.
# Safe to re-run: bash setup.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER="$ROOT/server"
GEYSER="$ROOT/geyser"
TOOLS="$ROOT/tools"
mkdir -p "$SERVER/plugins" "$GEYSER" "$TOOLS"
FAILED=()

echo "==> Installing tmux"
sudo apt-get update -qq && sudo apt-get install -y -qq tmux python3 curl >/dev/null \
  || FAILED+=("apt packages (tmux/python3/curl)")

# dl URL DEST MIN_BYTES : download and reject files that are suspiciously small (error pages)
dl() {
  local url="$1" dest="$2" min="${3:-100000}"
  curl -fsSL --retry 3 -A "Mozilla/5.0 (codespace setup)" -o "$dest.part" "$url" \
    || { rm -f "$dest.part"; return 1; }
  local size
  size=$(stat -c%s "$dest.part")
  if [ "$size" -lt "$min" ]; then rm -f "$dest.part"; return 1; fi
  mv "$dest.part" "$dest"
}

# modrinth SLUG DEST_DIR : download the newest release of a Modrinth plugin that supports bukkit/paper/spigot
modrinth() {
  python3 - "$1" "$2" <<'PY'
import json, sys, urllib.request, os
slug, dest = sys.argv[1], sys.argv[2]
hdr = {"User-Agent": "codespace-setup"}
req = urllib.request.Request(f"https://api.modrinth.com/v2/project/{slug}/version", headers=hdr)
versions = json.load(urllib.request.urlopen(req, timeout=30))
ok = lambda v: set(v.get("loaders", [])) & {"bukkit", "paper", "spigot"}
cands = [v for v in versions if v.get("version_type") == "release" and ok(v)] or [v for v in versions if ok(v)]
if not cands:
    sys.exit("no bukkit/paper/spigot build found")
v = cands[0]
f = next((x for x in v["files"] if x.get("primary")), v["files"][0])
out = os.path.join(dest, f["filename"])
req = urllib.request.Request(f["url"], headers=hdr)
open(out, "wb").write(urllib.request.urlopen(req, timeout=120).read())
print(f"   {slug}: {f['filename']} (version {v['version_number']})")
PY
}

echo "==> Paper 1.12.2"
bash "$ROOT/get-paper.sh" || FAILED+=("Paper 1.12.2 (run: bash get-paper.sh and read its message)")

echo "==> Plugins (Modrinth)"
for slug in eaglercraftxserver viaversion viabackwards viarewind; do
  modrinth "$slug" "$SERVER/plugins" || FAILED+=("plugin: $slug")
done

echo "==> WorldEdit 6.1.7.3 (the last line that supports 1.12)"
dl "https://dev.bukkit.org/projects/worldedit/files/2460562/download" \
   "$SERVER/plugins/worldedit-bukkit-6.1.7.3.jar" 1000000 \
  || FAILED+=("WorldEdit (download worldedit-bukkit-6.1.7.3.jar from CurseForge and put it in server/plugins/)")

echo "==> Geyser standalone (Bedrock support)"
dl "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/standalone" \
   "$GEYSER/Geyser-Standalone.jar" 5000000 || FAILED+=("Geyser standalone")

echo "==> playit.gg agent (free tunnel for Java + Bedrock)"
( curl -SsL https://playit-cloud.github.io/ppa/key.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null \
  && echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" | sudo tee /etc/apt/sources.list.d/playit-cloud.list >/dev/null \
  && sudo apt-get update -qq && sudo apt-get install -y -qq playit >/dev/null 2>&1 ) \
  || FAILED+=("playit apt package (see README: Tunnels)")
# (systemd errors during the apt install are normal in a Codespace)

echo "==> Server files"
# Accepting the Minecraft EULA: https://aka.ms/MinecraftEULA
echo "eula=true" > "$SERVER/eula.txt"
if [ ! -f "$SERVER/server.properties" ]; then
cat > "$SERVER/server.properties" <<'EOF'
online-mode=false
server-port=25565
motd=Eaglercraft + Java + Bedrock
max-players=20
view-distance=8
white-list=true
enforce-whitelist=true
EOF
fi

# Generate Geyser's config once, then switch it to offline auth to match online-mode=false
if [ -f "$GEYSER/Geyser-Standalone.jar" ] && [ ! -f "$GEYSER/config.yml" ]; then
  echo "==> Generating Geyser config (takes ~30s)"
  (cd "$GEYSER" && timeout 40 java -Xmx512M -jar Geyser-Standalone.jar --nogui >/dev/null 2>&1)
fi
if [ -f "$GEYSER/config.yml" ]; then
  sed -i 's/auth-type: *online/auth-type: offline/' "$GEYSER/config.yml"
  echo "   Geyser config ready (auth-type set to offline)"
else
  FAILED+=("Geyser config.yml was not generated (run: cd geyser && java -jar Geyser-Standalone.jar --nogui, then set auth-type: offline)")
fi

echo
echo "================ SETUP SUMMARY ================"
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "Everything downloaded. Next: bash start.sh"
else
  echo "These steps need attention:"
  for f in "${FAILED[@]}"; do echo "  - $f"; done
  echo "Fix them (or tell Claude the message above), then run: bash start.sh"
fi
