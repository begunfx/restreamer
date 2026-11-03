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
| HSTile ~2 min lag vs ~4s server live-edge | mitigated (player) | Stock Video.js ~10s behind seekable live; hls.js LL ~1s behind (~5s end-to-end with `hls_time 2`). See [[Latency]]. Tablet A/B still required after HSTile URL cutover. |
| Process UI / logs embed credentials in FFmpeg + HLS PUT URLs | fixed (core) | `begunfx/core` redacts URL userinfo + Basic auth on API process/config/progress/probe/report responses. |
| Wizard Silence Audio maps video twice / omits `anullsrc` (#954) | fixed (ui) | `begunfx/restreamer-ui` sets `profile.custom.selected` so `cleanupProfile` keeps audio source `1`. |
| Upstream latency threads (#974, #942, #934) | related | Player-side LL addresses the HSTile path; sub-second needs non-HLS egress. |

## In-scope upstream bugs (triaged)

Keep / watch:

| Upstream | Why in scope | Fork status |
|----------|----------------|-------------|
| [#975](https://github.com/datarhei/restreamer/issues/975) media playback aborted (browser) | Player/browser stability | watch |
| [#954](https://github.com/datarhei/restreamer/issues/954) wizard wrong channel config with silence audio | Channel setup correctness (video-only cameras) | **fixed** in Restreamer-UI |
| [#952](https://github.com/datarhei/restreamer/issues/952) RTMP pull breaks; HLS continues | Ingest reliability patterns | watch |
| [#943](https://github.com/datarhei/restreamer/issues/943) framerate passthrough from device | Device/camera ingest | watch |
| [#936](https://github.com/datarhei/restreamer/issues/936) audio lags behind video over time | A/V sync (mute HSTile path less critical) | watch |
| [#864](https://github.com/datarhei/restreamer/issues/864) no audio processing creates player error | Video-only UniFi streams | watch — prefer Silence Audio / No audio after #954 fix |
| [#863](https://github.com/datarhei/restreamer/issues/863) channel page reloads to setup | Core/UI stability | watch |

## Explicitly deferred (broadcast / unrelated)

Examples skipped for this use case: Facebook/Twitch/Instagram publish failures, OBS SRT desktop publish, Telegram RTMPS, high viewer-count playersite (#951), IIS reverse-proxy 403 (#957), SRT corrupt packets from OBS.

## Dependency pin (this bundle)

| Component | Pin (2026-11-03) |
|-----------|------------------|
| restreamer-ui | built from local `Restreamer-UI` → [begunfx/restreamer-ui](https://github.com/begunfx/restreamer-ui) (`1.14.1`, FFmpeg `^5 \|\| ^6 \|\| ^7 \|\| ^8`) |
| core | built from local `Restreamer-Core` → [begunfx/core](https://github.com/begunfx/core) (credential redaction) |
| ffmpeg | `datarhei/base:ffmpeg8.1.2-alpine3.23` |

Bundle Dockerfile stages UI+core under `_build/` via `make stage-sources` / `make deploy-datavault`.
