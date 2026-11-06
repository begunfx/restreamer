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

- Vendored `hls.js` `1.5.17`: `liveSyncDurationCount: 2`, `liveMaxLatencyDurationCount: 6`, `maxLiveSyncPlaybackRate: 1.1`, `maxBufferLength: 6`
- Catches up by playback rate (no seeking); hard jump only if lag > 12s
- Holding < 1 segment from the edge starves the buffer (measured 10 seeks + 15 stalls / 15s) — do not tighten below 2 target durations

## Street channel re-encode (restreamer-dev only, 2026-11-05)

Stream copy segments end on camera keyframes (~2–3s), which sets the latency floor. Dev Street output now re-encodes with a fixed 1s GOP:

```bash
-codec:v libx264 -preset veryfast -tune zerolatency -profile:v main -pix_fmt yuv420p \
  -r 30 -g 30 -keyint_min 30 -sc_threshold 0 -force_key_frames "expr:gte(t,n_forced*1)" \
  -b:v 700k -maxrate 900k -bufsize 900k \
  -hls_time 1 -hls_list_size 4
```

| Metric | Copy, `hls_time 2` (prod) | Re-encode, `hls_time 1` (dev) |
|--------|---------------------------|-------------------------------|
| Segment length | ~2–3s | 1.0s |
| Player behind playlist edge | ~12–18s (stock Video.js) | 1–2s |
| Camera OSD vs wall clock | ~20s | ~3s |
| Playback (30s sample) | — | 901 frames, 0 stalls, 0 dropped |
| `restreamer-dev` CPU | ~1% | ~24% of one core (Ryzen V1500B, 640x360) |

> [!WARNING] UI overwrite
> Applied via `PUT /api/v3/process/{id}`, not the Restreamer UI. Saving the Street channel in the UI regenerates FFmpeg options and can revert to `-codec:v copy` / `-hls_time 2`.

Restreamer's disk cache serves static files for up to 300s (`storage.disk.cache.ttl_seconds`); player updates can take 5 minutes to reach tablets.

## Validation checklist

1. Deploy `restreamer-dev` on **DataVault** (`make deploy-datavault` after SSH pubkey — [[SSH-Deploy-Setup]])
2. Create one test channel on DataVault `restreamer-dev` pulling the UniFi RTSP URL
3. Browser same-origin A/B on production Street already measured (table above)
4. On tablet, A/B once a channel exists on the LL host:
   - stock: `http://192.168.1.28:8085/<uuid>.html?autoplay=1&mute=1`
   - LL: `http://192.168.1.28:18085/hstile-player.html?id=<uuid>&autoplay=1&mute=1`
5. Compare against camera OSD / wall clock
6. Only after sign-off: cut over HSTile HTML files / production image


