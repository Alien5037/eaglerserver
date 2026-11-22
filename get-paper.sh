#!/usr/bin/env bash
# Downloads Paper 1.12.2 and the vanilla 1.12.2 server jar that Paper needs for its first-run patching.
# The old PaperMC v2 download API was shut down (HTTP 410), so this uses the current v3 API.
# Usage: bash get-paper.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER="$ROOT/server"
mkdir -p "$SERVER/cache"
UA="codespace-mc-setup (personal Minecraft server setup script)"

echo "==> Looking up Paper 1.12.2 in the PaperMC downloads service"
URL=$(curl -fsSL -A "$UA" https://fill.papermc.io/v3/projects/paper/versions/1.12.2/builds 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
builds = data if isinstance(data, list) else data.get("builds", [])
best = max(builds, key=lambda b: b["id"])
print(best["downloads"]["server:default"]["url"])
' 2>/dev/null)

if [ -z "$URL" ]; then
  echo "!! The PaperMC service has no Paper 1.12.2 build (or the request failed)."
  echo "   Output of the raw request, to show Claude:"
  curl -sS -A "$UA" -w '\nHTTP %{http_code}\n' https://fill.papermc.io/v3/projects/paper/versions/1.12.2/builds | head -c 600
  exit 1
fi

echo "==> Downloading $URL"
curl -fsSL -A "$UA" -o "$SERVER/paper.jar.part" "$URL" || { echo "!! Paper download failed"; exit 1; }
[ "$(stat -c%s "$SERVER/paper.jar.part")" -gt 1000000 ] || { echo "!! Paper file is too small"; rm -f "$SERVER/paper.jar.part"; exit 1; }
mv "$SERVER/paper.jar.part" "$SERVER/paper.jar"

# Paper 1.12.2 tries to fetch the vanilla jar from a Mojang address that no longer exists.
# Put the vanilla jar where Paper looks for it (its "cache" folder) so it skips the download.
echo "==> Downloading vanilla 1.12.2 server jar from Mojang"
VANILLA_SHA1="886945bfb2b978778c3a0288fd7fab09d315b25f"
curl -fsSL -A "$UA" -o "$SERVER/cache/mojang_1.12.2.jar" \
  "https://launcher.mojang.com/v1/objects/$VANILLA_SHA1/server.jar" \
  || { echo "!! Vanilla jar download failed"; exit 1; }
if echo "$VANILLA_SHA1  $SERVER/cache/mojang_1.12.2.jar" | sha1sum -c --quiet -; then
  echo "   vanilla jar checksum OK"
else
  echo "!! Vanilla jar checksum did not match. Delete server/cache/mojang_1.12.2.jar and tell Claude."
  exit 1
fi

echo
echo "Done. Now run: bash start.sh stop ; bash start.sh"
