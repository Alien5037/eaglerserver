# Minecraft 1.12.2 server: Java + Bedrock + Eaglercraft

Runs inside a free GitHub Codespace. Paper 1.12.2 with EaglercraftXServer, ViaVersion, ViaBackwards, ViaRewind, WorldEdit, plus Geyser (Bedrock) and a playit.gg tunnel (Java/Bedrock).

## How people connect

| Player type | Address | Goes through |
|---|---|---|
| Eaglercraft (browser) | `wss://<codespace-name>-25565.app.github.dev` (printed by `start.sh`) | Codespaces port forwarding |
| Java Edition | the TCP address playit.gg gives you | playit tunnel |
| Bedrock Edition | the UDP address + port playit.gg gives you | playit tunnel |

Codespaces can only forward web traffic, which is why Java and Bedrock use the playit tunnel.

## One-time setup

1. Create a new **empty** GitHub repo (private is fine).
2. Upload these 4 files to the repo root: `.devcontainer.json`, `setup.sh`, `start.sh`, `README.md`. (In the web UI: Add file > Upload files. If the dot-file doesn't show up in your file picker, use Add file > Create new file, name it `.devcontainer.json` and paste the contents.)
3. On the repo page: **Code > Codespaces > Create codespace on main**. Wait for the build; `setup.sh` runs by itself and prints a SETUP SUMMARY at the end. Anything it lists needs a manual fix.
4. In the Codespace terminal: `bash start.sh`

By running this you accept the Minecraft EULA (`setup.sh` writes `eula=true`): https://aka.ms/MinecraftEULA

## Tunnels for Java and Bedrock (playit.gg, free)

1. Run `bash start.sh` (it starts the playit daemon), then run `playit setup` once and open the claim link it prints. Make a playit account (email only) and approve the agent. Check it with `playit attach`.
2. In the playit dashboard, create two tunnels pointing at this agent:
   - **Minecraft Java** (TCP) to `127.0.0.1` port `25565`
   - **Minecraft Bedrock** (UDP) to `127.0.0.1` port `19132`
3. Share the addresses playit shows you. A brand-new Codespace needs `playit setup` again.

## Eaglercraft web client

Players need an EaglercraftX **1.8** web client (any hosted one works), then Multiplayer > Add Server > paste the `wss://` address. Hosting your own build on GitHub Pages is possible but not included here.

## Every time you play

- Start: `bash start.sh`
- Console: `tmux attach -t mc` (detach with Ctrl+B then D)
- **Stop when done:** `bash start.sh stop`, then stop the Codespace from the Codespaces menu. Free hours keep burning while it's running.
- Whitelist is on. Add people in the console: `whitelist add Name`. To open it up, set `white-list=false` in `server/server.properties`.

## Security note

`online-mode=false` means anyone can join using any name, including an op's name. Keep the whitelist on, and don't op names you haven't whitelisted.

## If something fails

- **Paper won't start on Java 17:** this setup runs Paper 1.12.2 on Java 17 because EaglercraftXServer needs it. If it crashes, tell Claude the error, or use the ready-made Paper 1.12.2 Eaglercraft server template from the Eaglercraft-Templates GitHub organization.
- **Eaglercraft won't connect:** make sure port 25565 is **Public** in the Ports tab, and that the address starts with `wss://`.
- **Bedrock won't connect:** check `tmux attach -t geyser` for errors, and confirm the UDP tunnel targets port 19132.
- **A plugin is missing in `server/plugins/`:** download it manually and drop it in, then restart.
