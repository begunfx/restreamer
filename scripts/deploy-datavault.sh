#!/usr/bin/env bash
# Deploy restreamer-dev to DataVault without touching production restreamer.
#
# macOS /usr/bin/rsync (openrsync) fails against Synology SSH ("Permission denied"),
# so we stream a tarball over SSH and run Linux rsync on the NAS.
#
# Auth: SSH public-key only (Host alias datavault + explicit identity).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXCLUDE_FILE="$ROOT/scripts/rsync-excludes.txt"

if [[ -f "$ROOT/deploy.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/deploy.env"
  set +a
fi

DEPLOY_SSH_HOST="${DEPLOY_SSH_HOST:-datavault}"
DEPLOY_PATH="${DEPLOY_PATH:-/volume1/docker/restreamer-dev}"
DEPLOY_SSH_IDENTITY="${DEPLOY_SSH_IDENTITY:-$HOME/.ssh/id_ed25519_datavault}"
DRY_RUN=0
SYNC_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --sync-only) SYNC_ONLY=1 ;;
    -h|--help)
      cat <<'HELP'
Deploy restreamer-dev to DataVault via SSH key auth.
Does not touch production /volume1/docker/restreamer.

  ./scripts/deploy-datavault.sh
  ./scripts/deploy-datavault.sh --dry-run
  ./scripts/deploy-datavault.sh --sync-only

Uses tar-over-SSH + remote Linux rsync (macOS openrsync is incompatible with Synology).
HELP
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:${PATH:-}"

if [[ ! -f "$EXCLUDE_FILE" ]]; then
  echo "Missing exclude file: $EXCLUDE_FILE" >&2
  exit 1
fi
if [[ ! -f "$DEPLOY_SSH_IDENTITY" ]]; then
  echo "SSH identity not found: $DEPLOY_SSH_IDENTITY" >&2
  echo "See docs/SSH-Deploy-Setup.md" >&2
  exit 1
fi

# LogLevel=ERROR hides OpenSSH "post-quantum KEX" warnings against Synology's older sshd (LAN-safe).
SSH_BASE=(ssh -o BatchMode=yes -o ConnectTimeout=15 -o IdentitiesOnly=yes -o LogLevel=ERROR -i "$DEPLOY_SSH_IDENTITY")

echo "==> Target: ${DEPLOY_SSH_HOST}:${DEPLOY_PATH}"
echo "==> Identity: ${DEPLOY_SSH_IDENTITY}"
echo "==> Sync method: tar-over-SSH + remote rsync (prod restreamer untouched)"

if ! "${SSH_BASE[@]}" "$DEPLOY_SSH_HOST" "true"; then
  cat <<EOF >&2
SSH key auth failed for Host '${DEPLOY_SSH_HOST}'.
Test:  ssh ${DEPLOY_SSH_HOST} 'echo ok'
See docs/SSH-Deploy-Setup.md
EOF
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "==> DRY RUN — would stream project tarball and remote-rsync into ${DEPLOY_PATH}"
  echo "==> Excludes:"
  cat "$EXCLUDE_FILE"
  exit 0
fi

"${SSH_BASE[@]}" "$DEPLOY_SSH_HOST" "mkdir -p '${DEPLOY_PATH}/config' '${DEPLOY_PATH}/data'"

TAR_EXCLUDES=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  TAR_EXCLUDES+=(--exclude="$line")
done < "$EXCLUDE_FILE"

STAGE="/tmp/restreamer-dev-deploy-$$"
echo "==> Streaming files to DataVault…"

export COPYFILE_DISABLE=1
tar -C "$ROOT" "${TAR_EXCLUDES[@]}" -cf - . \
  | "${SSH_BASE[@]}" "$DEPLOY_SSH_HOST" \
    "set -euo pipefail; \
     STAGE='${STAGE}'; \
     DEPLOY_PATH='${DEPLOY_PATH}'; \
     rm -rf \"\$STAGE\"; mkdir -p \"\$STAGE\" \"\$DEPLOY_PATH\"; \
     tar -C \"\$STAGE\" -xf -; \
     rsync -a --delete \
       --exclude 'config/' \
       --exclude 'data/' \
       \"\$STAGE\"/ \"\$DEPLOY_PATH\"/; \
     rm -rf \"\$STAGE\"; \
     echo remote_sync_ok"

if [[ "$SYNC_ONLY" -eq 1 ]]; then
  echo "==> Sync-only complete (no build/recreate)"
  exit 0
fi

echo "==> Building image + recreating restreamer-dev on DataVault"
"${SSH_BASE[@]}" "$DEPLOY_SSH_HOST" bash -s <<EOF
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\${PATH:-}"
cd '${DEPLOY_PATH}'
mkdir -p config data
chmod u+rwX,g+rwX config data 2>/dev/null || true

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found even with /usr/local/bin in PATH" >&2
  ls -la /usr/local/bin/docker >&2 || true
  exit 1
fi

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
  if sudo -n docker info >/dev/null 2>&1; then
    DOCKER=(sudo -n docker)
  else
    echo "Cannot access Docker daemon as \$(whoami)." >&2
    echo "Socket is typically root-only on Synology." >&2
    echo "Configure passwordless sudo for docker (same pattern as MediaVault)." >&2
    exit 1
  fi
fi

# Synology often lacks buildx; force classic builder when buildx is missing.
if "\${DOCKER[@]}" buildx version >/dev/null 2>&1; then
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1
  "\${DOCKER[@]}" buildx build --load -t restreamer-dev:local .
else
  export DOCKER_BUILDKIT=0
  export COMPOSE_DOCKER_CLI_BUILD=0
  "\${DOCKER[@]}" build -t restreamer-dev:local .
fi

compose() {
  if "\${DOCKER[@]}" compose version >/dev/null 2>&1; then
    "\${DOCKER[@]}" compose "\$@"
  else
    if [[ "\${DOCKER[0]}" == sudo ]]; then
      sudo -n docker-compose "\$@"
    else
      docker-compose "\$@"
    fi
  fi
}
if [[ -f docker-compose.portainer.yml ]]; then
  compose -f docker-compose.portainer.yml up -d --force-recreate --remove-orphans
else
  compose up -d --force-recreate --remove-orphans
fi
"\${DOCKER[@]}" ps --filter name=restreamer-dev --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
echo "Health check:"
curl -sf --connect-timeout 5 -o /dev/null -w 'ui_http=%{http_code}\n' http://127.0.0.1:18085/ui/ || true
EOF

echo "==> Deploy finished"
echo "    Target host:   ${DEPLOY_SSH_HOST}"
echo "    Path:          ${DEPLOY_PATH}"
echo "    UI:            http://${DEPLOY_SSH_HOST}:18085/ui/  (or NAS IP)"
echo "    HSTile player: http://${DEPLOY_SSH_HOST}:18085/hstile-player.html?id=<channel-uuid>&autoplay=1&mute=1"
echo "    Production restreamer on DataVault :8085 was not modified."

