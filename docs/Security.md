---
creation_date: 2026-11-03
status: status/active
project: "[[Homelab Migration]]"
tags:
  - hardware/synology
  - task/pending
---

# Security Notes — Restreamer (begunfx fork)

## Trust boundary

| Surface | Auth | Notes |
|---------|------|-------|
| Admin UI `/ui/` | Login (JWT) | Keep on trusted LAN / Authentik as configured |
| Public channel player `/{uuid}.html` | None (by design) | HSTile iframes this; LAN-only exposure |
| HLS `/memfs/*.m3u8` | None (by design) | Same trust boundary as player pages |
| HSTile low-latency `/hstile-player.html` | None (by design) | Same trust boundary; query `id` must be a known channel UUID |

> [!WARNING] Public players
> Player + memfs routes are intentionally unauthenticated for tablet iframes. Do not publish Restreamer ports to the internet without an allowlist / reverse-proxy auth strategy that still allows HSTile.

## Pre-ship audit (fork additions, 2026-11-03)

Audited surfaces added in this fork before any production cutover:

| Finding | Severity | Disposition |
|---------|----------|-------------|
| `/hstile-player.html?id=` reflected into stream URL | Low | `id` passed through `encodeURIComponent`; status uses `textContent` (no HTML injection) |
| Vendored `hls.min.js` served from data root | Info | Same public trust boundary as memfs; no CDN required on tablets |
| Deploy script SSH | Info | Key-only; `deploy.env` gitignored; never syncs remote `config/` or `data/` |
| Process details embed RTSP + admin basic-auth in FFmpeg/HLS PUT URLs | High → fixed | `begunfx/core` redacts credentials on API marshal of process command/config/progress/probe/logs |
| Stock Video.js players remain public | Info | Intentional for HSTile; LL player is additive |

## Known issues to harden

- **Secrets in git** — never commit `deploy.env`, RTSP URLs with tokens, or admin passwords. Redact as `<REDACTED>` in docs.
- **Dev vs prod isolation** — `restreamer-dev` uses separate volumes and ports (`18085` etc.). Do not point production HSTile tiles at dev until cutover is approved.
- **Stored process configs** — DB still holds real URLs for FFmpeg execution; redaction is on API responses only.

## Deploy hygiene

- SSH public-key only (see [[SSH-Deploy-Setup]])
- Deploy sync excludes remote `config/` and `data/`
- Pre-ship gate: audit → fix blockers → then replace production `datarhei/restreamer:latest` (this document is the audit record for fork additions)

## Residual risk (accepted)

- Public unauthenticated HLS/player on LAN (intentional for HSTile)
- Credentials remain in on-disk process DB for runtime; protect admin UI and NAS filesystem access
