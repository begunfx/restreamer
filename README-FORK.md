---
creation_date: 2026-11-03
status: status/active
project: "[[Homelab Migration]]"
tags:
  - hardware/synology
---

# begunfx/restreamer — local workspace notes

Upstream README remains in [[README]]. This file is fork/homelab ops.

## Workspace layout

Sibling to [[LiveTV-Consolidator]] under the Obsidian vault. Nested git repo; vault `.gitignore` excludes `Restreamer/`.

| Path | Purpose |
|------|---------|
| `Dockerfile` / `run.sh` | Bundle image + HSTile player install into `/core/data` |
| `hstile/` | Low-latency HSTile player + vendored `hls.min.js` |
| `scripts/deploy-datavault.sh` | LiveTV-style tar-over-SSH deploy to DataVault |
| `docker-compose.portainer.yml` | `restreamer-dev` stack (ports `18085`+) |
| `docs/` | SSH, security, latency, bug backlog |
| `DEPLOY-DataVault.md` | Operator deploy guide |

## Quick start

1. Complete [[docs/SSH-Deploy-Setup]]
2. `make deploy-datavault`
3. Open `http://192.168.1.28:18085/ui/` and create a test channel
4. Point a test HSTile iframe at `/hstile-player.html?id=<uuid>&autoplay=1&mute=1`

See [[docs/Latency]] and [[DEPLOY-DataVault]].
