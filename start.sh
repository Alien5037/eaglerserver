#!/usr/bin/env bash
# Usage:
#   bash start.sh        start everything (Paper, Geyser, playit tunnel)
#   bash start.sh stop   stop everything cleanly (do this when you're done: it saves Codespace hours)
#   bash start.sh status show what is running
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run() { # run NAME DIR COMMAND
  if tmux has-session -t "$1" 2>/dev/null; then
    echo "  $1 is already running"
  else
    tmux new-session -d -s "$1" -c "$2" "$3; echo; echo '--- $1 exited, press Enter ---'; read"
    echo "  started $1"
  fi
}

case "${1:-start}" in
  stop)
    tmux send-keys -t mc "stop" Enter 2>/dev/null
    echo "Waiting for the world to save..."
    sleep 10
    tmux kill-session -t geyser 2>/dev/null
    tmux kill-session -t playit 2>/dev/null
    tmux kill-session -t mc 2>/dev/null
    echo "Stopped. You can now stop the Codespace (Codespaces menu > Stop current codespace)."
    exit 0
    ;;
  status)
    tmux ls 2>/dev/null || echo "Nothing running."
    exit 0
    ;;
esac

echo "Starting..."
# Paper 1.12.2 on Java 17 needs the IgnoreJavaVersion flag; EaglercraftXServer needs Java 17+.
run mc "$ROOT/server" "java -Xms1G -Xmx3G -DPaper.IgnoreJavaVersion=true \
  --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED \
  --add-opens java.base/java.lang.reflect=ALL-UNNAMED --add-opens java.base/java.net=ALL-UNNAMED \
  -jar paper.jar nogui"

[ -f "$ROOT/geyser/Geyser-Standalone.jar" ] && run geyser "$ROOT/geyser" "java -Xmx512M -jar Geyser-Standalone.jar --nogui"

if [ -x "$ROOT/tools/playit" ]; then
  if [ -n "${PLAYIT_SECRET:-}" ]; then
    run playit "$ROOT/tools" "./playit -s \"$PLAYIT_SECRET\""
  else
    run playit "$ROOT/tools" "./playit"
  fi
fi

# Try to make the web port public so Eaglercraft players can connect
if [ -n "${CODESPACE_NAME:-}" ]; then
  gh codespace ports visibility 25565:public -c "$CODESPACE_NAME" >/dev/null 2>&1 \
    && echo "  port 25565 set to public" \
    || echo "  could not set port 25565 public automatically: open the Ports tab, right-click 25565 > Port Visibility > Public"
  echo
  echo "Eaglercraft address:  wss://${CODESPACE_NAME}-25565.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
fi
echo
echo "Console:        tmux attach -t mc        (detach with Ctrl+B then D)"
echo "Tunnel/claim:   tmux attach -t playit    (first run prints a link to claim the tunnel)"
echo "Bedrock log:    tmux attach -t geyser"
echo "Whitelist:      in the mc console type  whitelist add PlayerName"
