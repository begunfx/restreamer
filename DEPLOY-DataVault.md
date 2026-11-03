---
creation_date: 2026-11-03
status: status/active
project: "[[Homelab Migration]]"
tags:
  - hardware/synology
  - task/pending
---

# Deploy restreamer-dev on DataVault (Portainer Stack)

## Goal

Isolated **dev** Restreamer on DataVault for lag/security validation. Production stack `restreamer` on `:8085` stays untouched until you sign off.

| Instance | Container | Host UI port | Config path |
|----------|-----------|--------------|-------------|
| Production | `restreamer` | `8085` | `/volume1/docker/restreamer/` |
| Dev | `restreamer-dev` | `18085` | `/volume1/docker/restreamer-dev/` |

Dev also maps: `18181→8181`, `11935→1935`, `11936→1936`, `16000/udp→6000/udp`.

## Remote

Git origin: `https://github.com/begunfx/restreamer.git` (fork of `datarhei/restreamer`).

## Automated deploy

**Credentials:** SSH public key only — see [[docs/SSH-Deploy-Setup]]. Never put NAS passwords in scripts.

```bash
# One-time: create key, install .pub on NAS, add ~/.ssh/config (docs/SSH-Deploy-Setup.md)
ssh datavault 'echo ok'

cp deploy.env.example deploy.env   # optional overrides

# Build image + recreate restreamer-dev on DataVault
make deploy-datavault
```

What it does:

1. Stages sibling `Restreamer-UI` + `Restreamer-Core` into `_build/` (begunfx forks)
2. Streams project tarball over SSH into `/volume1/docker/restreamer-dev` (excludes `config/` + `data/` so runtime state is preserved)
3. Multi-stage `docker build` on DataVault: yarn UI + Go core + `datarhei/base:ffmpeg8.1.2-alpine3.23`
4. `docker compose -f docker-compose.portainer.yml up -d --force-recreate`

Owned stack remotes:

- Bundle: [begunfx/restreamer](https://github.com/begunfx/restreamer)
- UI: [begunfx/restreamer-ui](https://github.com/begunfx/restreamer-ui)
- Core: [begunfx/core](https://github.com/begunfx/core)

Optional:

```bash
make deploy-datavault-dry
make deploy-datavault-sync
```

## HSTile low-latency player

After container start, assets are copied into `/core/data`:

- `http://192.168.1.28:18085/hstile-player.html?id=<channel-uuid>&autoplay=1&mute=1`

Example (Street channel UUID from production player URL):

```text
http://192.168.1.28:18085/hstile-player.html?id=77f4ab3c-158e-4099-8002-d8542b1afd10&autoplay=1&mute=1
```

Point a **test** HSTile iframe at that URL; leave production tiles on `:8085` until lag is validated.

## Verify

```bash
curl -sI http://192.168.1.28:18085/ui/
curl -sI "http://192.168.1.28:18085/hstile-player.html"
docker logs restreamer-dev --tail 50   # on DataVault
```

## Cutover (later, explicit approval only)

1. Confirm tablet lag on `restreamer-dev` HSTile player is acceptable
2. Either rebuild production image from this fork, or retarget HSTile iframes to the low-latency player on production ports
3. Do not overwrite `/volume1/docker/restreamer` config/data without a backup
