#!/usr/bin/env bash
set -euo pipefail

log() { echo "[publish-wiki] $*"; }

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "GITHUB_TOKEN is required" >&2
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

if [[ ! -d "docs" ]]; then
  echo "docs/ directory not found" >&2
  exit 1
fi

SOURCE_SHA="${GITHUB_SHA:-local}"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  SOURCE_SHA="$(git rev-parse --short HEAD)"
fi

WIKI_DIR="$(mktemp -d)"
trap 'rm -rf "$WIKI_DIR"' EXIT

WIKI_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git"

log "Cloning wiki for ${GITHUB_REPOSITORY}"
if ! git clone --depth=1 "$WIKI_URL" "$WIKI_DIR" 2>/dev/null; then
  log "Wiki repo missing; initializing"
  mkdir -p "$WIKI_DIR"
  git -C "$WIKI_DIR" init
  git -C "$WIKI_DIR" remote add origin "$WIKI_URL"
  git -C "$WIKI_DIR" checkout -b master 2>/dev/null || git -C "$WIKI_DIR" checkout -b main
fi

log "Syncing docs/ to wiki"
rsync -a --delete --exclude='.git' docs/ "$WIKI_DIR/"

# Normalize markdown links for GitHub Wiki (strip .md suffix from internal links).
if command -v find >/dev/null 2>&1; then
  while IFS= read -r -d '' file; do
    if sed --version >/dev/null 2>&1; then
      sed -i -E 's/\]\(([^)#]+)\.md\)/](\1)/g' "$file"
      sed -i -E 's/\]\(\.\.\/([^)#]+)\)/](\1)/g' "$file"
    else
      sed -i '' -E 's/\]\(([^)#]+)\.md\)/](\1)/g' "$file"
      sed -i '' -E 's/\]\(\.\.\/([^)#]+)\)/](\1)/g' "$file"
    fi
  done < <(find "$WIKI_DIR" -name '*.md' -print0)
fi

git -C "$WIKI_DIR" config user.name "github-actions[bot]"
git -C "$WIKI_DIR" config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git -C "$WIKI_DIR" add -A
if git -C "$WIKI_DIR" diff --cached --quiet; then
  log "Wiki already up to date"
  exit 0
fi

git -C "$WIKI_DIR" commit -m "Sync docs from ${SOURCE_SHA}"
BRANCH="$(git -C "$WIKI_DIR" branch --show-current 2>/dev/null || echo master)"
git -C "$WIKI_DIR" push origin "HEAD:${BRANCH}"
log "Wiki published (${BRANCH})"
