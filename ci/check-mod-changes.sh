#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

write_output() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$1=$2" >> "$GITHUB_OUTPUT"
  fi
}

test_mod_version_format() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]
}

get_mod_release_version() {
  if [ -n "${NEXUS_MOD_VERSION:-}" ]; then
    if ! test_mod_version_format "$NEXUS_MOD_VERSION"; then
      echo "NEXUS_MOD_VERSION must be major.minor (e.g. 2.0); got: $NEXUS_MOD_VERSION" >&2
      exit 1
    fi
    echo "$NEXUS_MOD_VERSION"
    return
  fi

  local version_file="ci/MOD_VERSION"
  if [ -f "$version_file" ]; then
    local from_file
    from_file="$(tr -d '\r\n' < "$version_file")"
    if ! test_mod_version_format "$from_file"; then
      echo "Invalid ci/MOD_VERSION format (expected major.minor e.g. 2.0): $from_file" >&2
      exit 1
    fi
    echo "$from_file"
    return
  fi

  echo "2.0"
}

get_changed_files() {
  local before="${GITHUB_EVENT_BEFORE:-}"
  local after="${GITHUB_SHA:-}"

  if [ -n "$before" ] && [ -n "$after" ] && [ "$before" != "0000000000000000000000000000000000000000" ]; then
    git diff --name-only "$before" "$after" 2>/dev/null || true
    return
  fi

  if [ -n "$after" ]; then
    git diff-tree --no-commit-id --name-only -r "$after" 2>/dev/null || true
    return
  fi

  git diff --name-only HEAD~1 HEAD 2>/dev/null || true
}

test_mod_content_changed() {
  if [ "${FORCE_PUBLISH:-}" = "true" ]; then
    log "Mod content check skipped (force publish)"
    return 0
  fi

  mapfile -t changed_files < <(get_changed_files)
  if [ "${#changed_files[@]}" -eq 0 ]; then
    log "No changed files detected for release check"
    return 1
  fi

  local patterns=(
    '^LICENSE$'
    '^Packaged/'
    '^Source/'
    '^Images/'
    '^Licence/'
  )

  log "Release path check saw ${#changed_files[@]} changed file(s)"
  for file in "${changed_files[@]}"; do
    [ -z "$file" ] && continue
    local normalized="${file//\\//}"
    for pattern in "${patterns[@]}"; do
      if [[ "$normalized" =~ $pattern ]]; then
        log "Mod content changed: $normalized"
        return 0
      fi
    done
  done

  log "No mod content paths changed; skipping Nexus and GitHub release"
  return 1
}

release_version="$(get_mod_release_version)"
should_publish=false
if test_mod_content_changed; then
  should_publish=true
fi

log "Release check: should_publish=$should_publish release_version=$release_version"
write_output should_publish "$should_publish"
write_output release_version "$release_version"
log "Change check finished"
