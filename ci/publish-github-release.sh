#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGED_DIR="$REPO_ROOT/Packaged"
CONTENT_MODS=(RealisticCraft RealisticCraft_Plus RealisticStorage RealisticScans)

RELEASE_VERSION="${1:-}"
if [ -z "$RELEASE_VERSION" ]; then
  echo "Usage: publish-github-release.sh <release_version>" >&2
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

ensure_content_zips() {
  local zip_files=()
  for mod_name in "${CONTENT_MODS[@]}"; do
    local zip_path="$PACKAGED_DIR/$mod_name.zip"
    if [ ! -f "$zip_path" ]; then
      fail "Expected packaged zip not found: $zip_path"
    fi
    zip_files+=("$zip_path")
  done
  printf '%s\n' "${zip_files[@]}"
}

if [ "${GITHUB_ACTIONS:-}" != "true" ]; then
  log "Skipping GitHub release (not running on GitHub Actions)"
  write_output published false
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  fail "GitHub CLI (gh) not found; cannot publish release assets"
fi

mapfile -t zip_files < <(ensure_content_zips)
if [ "${#zip_files[@]}" -eq 0 ]; then
  fail "No zip files were built for GitHub release"
fi

tag="${GITHUB_RELEASE_TAG:-v${RELEASE_VERSION}}"
title="${GITHUB_RELEASE_TITLE:-Realistic Survival v${RELEASE_VERSION}}"
notes="${GITHUB_RELEASE_NOTES:-${GITHUB_EVENT_HEAD_COMMIT_MESSAGE:-Automated mod package build.}}"

log "Creating GitHub release $tag with ${#zip_files[@]} asset(s)"
gh release create "$tag" \
  --title "$title" \
  --notes "$notes" \
  "${zip_files[@]}"

release_url="https://github.com/${GITHUB_REPOSITORY}/releases/tag/${tag}"
write_output published true
write_output release_tag "$tag"
write_output release_url "$release_url"
log "Published GitHub release: $tag"
