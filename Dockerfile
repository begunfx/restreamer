# begunfx Restreamer bundle — owns UI + core + FFmpeg 8.
# Build context must include:
#   _build/restreamer-ui/   (from sibling Restreamer-UI)
#   _build/core/            (from sibling Restreamer-Core)
#
# Deploy path: scripts/deploy-datavault.sh stages those dirs before docker build.

ARG FFMPEG_IMAGE=datarhei/base:ffmpeg8.1.2-alpine3.23
ARG NODE_IMAGE=node:21-alpine3.20
ARG GOLANG_IMAGE=golang:1.22-alpine3.19

# --- UI (begunfx/restreamer-ui) ---
FROM $NODE_IMAGE AS restreamer-ui

ENV PUBLIC_URL="./"

COPY _build/restreamer-ui /ui
WORKDIR /ui

RUN yarn install && yarn build

# --- Core (begunfx/core) — native build (Synology classic builder has no buildx) ---
FROM $GOLANG_IMAGE AS core-builder

COPY _build/core /dist/core

RUN apk add --no-cache git make \
	&& cd /dist/core \
	&& make release \
	&& make import \
	&& make ffmigrate

# --- Bundle on FFmpeg 8 ---
FROM $FFMPEG_IMAGE

COPY --from=core-builder /dist/core/core /core/bin/core
COPY --from=core-builder /dist/core/import /core/bin/import
COPY --from=core-builder /dist/core/ffmigrate /core/bin/ffmigrate
COPY --from=core-builder /dist/core/mime.types /core/mime.types
COPY --from=restreamer-ui /ui/build /core/ui
RUN mkdir -p /core/config /core/data

COPY ./CHANGELOG.md /core/ui/CHANGELOG.md
COPY ./run.sh /core/bin/run.sh
COPY ./ui-root /core/ui-root
COPY ./hstile /core/ui-root/hstile

RUN ffmpeg -buildconf

ENV CORE_CONFIGFILE=/core/config/config.json
ENV CORE_DB_DIR=/core/config
ENV CORE_ROUTER_UI_PATH=/core/ui
ENV CORE_STORAGE_DISK_DIR=/core/data

EXPOSE 8080/tcp
EXPOSE 8181/tcp
EXPOSE 1935/tcp
EXPOSE 1936/tcp
EXPOSE 6000/udp

VOLUME ["/core/data", "/core/config"]
ENTRYPOINT ["/core/bin/run.sh"]
WORKDIR /core
