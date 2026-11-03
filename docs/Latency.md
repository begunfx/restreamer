---
creation_date: 2026-11-03
status: status/active
project: "[[Homelab Migration]]"
tags:
  - hardware/synology
  - task/pending
---

# Latency notes (UniFi → Restreamer → HSTile)

## Measured production path (2026-11-03)

- HSTile iframe loads stock Restreamer Video.js page, e.g. `http://datavault:8085/<uuid>.html?autoplay=1&mute=1`
- Street channel FFmpeg (redacted): RTSP from `192.168.1.63:7447`, `-codec:v copy`, HLS `-hls_time 2 -hls_list_size 6`
- Playlist `#EXT-X-PROGRAM-DATE-TIME` vs wall clock: **~3–4 seconds** server live-edge
- Reported tablet lag: **~2 minutes** → not explained by HLS segment settings alone; player/buffer/iframe path is the primary suspect

### Browser A/B on Street player (`…/77f4ab3c-….html`)

| Mode | Server PDT lag | Player behind seekable live edge | Approx display lag |
|------|----------------|----------------------------------|--------------------|
| Stock Video.js | ~3.1s | ~10.1s | ~13s |
| hls.js low-latency (same stream) | ~4.1s | ~1.0s | ~5s |

Residual floor for HLS with `hls_time 2` + 1 segment sync is roughly **~4–6s** in-browser. Near-zero (sub-second) needs a non-HLS egress HSTile can play (future work if required).

## Dev mitigation in this fork

Custom player: `/hstile-player.html?id=<uuid>&autoplay=1&mute=1`

- Vendored `hls.js` with `lowLatencyMode`, short buffers, `liveSyncDurationCount: 1`
- Seeks toward live edge on start
- Periodic resync if lag drifts above 8s

## Validation checklist

1. Deploy `restreamer-dev` on **DataVault** (`make deploy-datavault` after SSH pubkey — [[SSH-Deploy-Setup]])
2. Create one test channel on DataVault `restreamer-dev` pulling the UniFi RTSP URL
3. Browser same-origin A/B on production Street already measured (table above)
4. On tablet, A/B once a channel exists on the LL host:
   - stock: `http://192.168.1.28:8085/<uuid>.html?autoplay=1&mute=1`
   - LL: `http://192.168.1.28:18085/hstile-player.html?id=<uuid>&autoplay=1&mute=1`
5. Compare against camera OSD / wall clock
6. Only after sign-off: cut over HSTile HTML files / production image


