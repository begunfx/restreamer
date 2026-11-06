---
creation_date: 2026-11-03
status: status/active
project: "[[Homelab Migration]]"
tags:
  - task/pending
---

# Bug backlog (UniFi / HSTile scoped)

Source of truth: open **bug**-labeled issues on upstream [datarhei/restreamer](https://github.com/datarhei/restreamer/issues?q=is%3Aissue+is%3Aopen+label%3Abug).

**In scope:** RTSP/UniFi ingest, HLS/player delivery, core stability for local camera→tablet use.

**Out of scope for now:** broadcast/platform features (YouTube, Twitch, Facebook, Instagram, Telegram, OBS SRT publish, etc.).

## Priority for this fork

| Item | Status | Notes |
|------|--------|-------|
| HSTile lag vs camera OSD | mitigated (dev) | Dev Street re-encodes 1s GOP + LL player ≈ **3s** end-to-end. Prod stock Video.js still ≈20s. See [[Latency]]. |
| Process UI / logs embed credentials in FFmpeg + HLS PUT URLs | fixed (core) | `begunfx/core` redacts URL userinfo + Basic auth on API process/config/progress/probe/report responses. |
| Wizard Silence Audio maps video twice / omits `anullsrc` (#954) | fixed (ui) | `begunfx/restreamer-ui` sets `profile.custom.selected` so `cleanupProfile` keeps audio source `1`. |
| FFmpeg 8 stale-timeout kill loop | fixed (core) | Progress parser strips `[info]` log-level prefix so `ffmpeg.progress` resets the watcher. |
| Upstream latency threads (#974, #942, #934) | related | Player-side LL + 1s GOP on dev; sub-second needs non-HLS egress. |

## In-scope upstream bugs (triaged)

| Upstream | Why in scope | Fork status |
|----------|----------------|-------------|
| [#954](https://github.com/datarhei/restreamer/issues/954) wizard wrong channel config with silence audio | Channel setup correctness (video-only cameras) | **fixed** in Restreamer-UI |
| [#943](https://github.com/datarhei/restreamer/issues/943) framerate passthrough from device | Device/camera ingest | **fixed** — omit `-r` when `-fps_mode` is `passthrough`/`vfr` |
| [#936](https://github.com/datarhei/restreamer/issues/936) audio lags behind video over time | A/V sync on capture/ALSA | **fixed** — auto `aresample=async=1` on encoded audio |
| [#864](https://github.com/datarhei/restreamer/issues/864) audio copy breaks browser HLS | Network cams with AAC audio | **fixed** — restore `-bsf:a aac_adtstoasc` on audio copy |
| [#863](https://github.com/datarhei/restreamer/issues/863) channel page reloads to setup | Core/UI stability | **fixed** — keep Main mounted across transient null process state |
| [#975](https://github.com/datarhei/restreamer/issues/975) media playback aborted (browser) | Player/browser stability | **deferred** — reporter attributed to NVIDIA driver; not reproducible here |
| [#952](https://github.com/datarhei/restreamer/issues/952) RTMP pull breaks; HLS continues | RTMP egress to OBS | **deferred** — broadcast/RTMP path; HSTile uses HLS; RTMP disabled on restreamer-dev |

## Explicitly deferred (broadcast / unrelated)

Examples skipped for this use case: Facebook/Twitch/Instagram publish failures, OBS SRT desktop publish, Telegram RTMPS, high viewer-count playersite (#951), IIS reverse-proxy 403 (#957), SRT corrupt packets from OBS.

## Dependency pin (this bundle)

| Component | Pin (2026-11-03) |
|-----------|------------------|
| restreamer-ui | built from local `Restreamer-UI` → [begunfx/restreamer-ui](https://github.com/begunfx/restreamer-ui) (`1.14.1`, FFmpeg `^5 \|\| ^6 \|\| ^7 \|\| ^8`) |
| core | built from local `Restreamer-Core` → [begunfx/core](https://github.com/begunfx/core) (credential redaction) |
| ffmpeg | `datarhei/base:ffmpeg8.1.2-alpine3.23` |

Bundle Dockerfile stages UI+core under `_build/` via `make stage-sources` / `make deploy-datavault`.
