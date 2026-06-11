#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/ci/MOD_VERSION"

RELEASE_VERSION="${1:-}"
if [ -z "$RELEASE_VERSION" ]; then
  echo "Usage: bump-mod-version.sh <release_version>" >&2
  exit 1
fi

if ! [[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "Release version must be major.minor (e.g. 2.0); got: $RELEASE_VERSION" >&2
  exit 1
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

write_output() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$1=$2" >> "$GITHUB_OUTPUT"
  fi
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

get_next_version() {
  local current="$1"
  local major minor
  IFS='.' read -r major minor <<< "$current"
  echo "$((major)).$((minor + 1))"
}

next_version=""
if [ -n "${NEXUS_MOD_VERSION:-}" ]; then
  log "Skipping version bump (NEXUS_MOD_VERSION override was used)"
elif [ "${SKIP_VERSION_BUMP:-}" = "true" ]; then
  log "Skipping version bump (SKIP_VERSION_BUMP=true)"
else
  next_version="$(get_next_version "$RELEASE_VERSION")"
  mkdir -p "$(dirname "$VERSION_FILE")"
  printf '%s' "$next_version" > "$VERSION_FILE"
  log "Updated ci/MOD_VERSION: $RELEASE_VERSION -> $next_version"
fi

if [ -n "$next_version" ] && [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  if command -v git >/dev/null 2>&1; then
  (
    cd "$REPO_ROOT"
    git config user.name 'github-actions[bot]'
    git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    git add -- ci/MOD_VERSION
    if git diff --cached --quiet -- ci/MOD_VERSION; then
      log "No MOD_VERSION change to commit"
    else
      git commit -m "chore: bump mod release version to $next_version [skip ci]"
      git push
      log "Committed and pushed MOD_VERSION bump to $next_version"
    fi
  )
  else
    log "git not found; leaving version bump uncommitted"
  fi
elif [ -n "$next_version" ]; then
  log "Version file updated locally; not committing outside GitHub Actions"
fi

write_output release_version "$RELEASE_VERSION"
write_output next_release_version "${next_version:-}"
log "Version bump phase finished"
