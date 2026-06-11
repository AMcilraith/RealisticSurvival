#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGED_DIR="$REPO_ROOT/Packaged"
NEXUS_API_BASE="${NEXUSMODS_API_BASE:-https://api.nexusmods.com/v3}"
NEXUS_API_BASE="${NEXUS_API_BASE%/}"

RELEASE_VERSION="${NEXUS_MOD_VERSION:-${1:-}}"
if [ -z "$RELEASE_VERSION" ] && [ -f "$REPO_ROOT/ci/MOD_VERSION" ]; then
  RELEASE_VERSION="$(tr -d '\r\n' < "$REPO_ROOT/ci/MOD_VERSION")"
fi
if [ -z "$RELEASE_VERSION" ]; then
  echo "Usage: publish-nexus.sh <release_version> (or set NEXUS_MOD_VERSION)" >&2
  exit 1
fi

if ! [[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "Release version must be major.minor (e.g. 2.0); got: $RELEASE_VERSION" >&2
  exit 1
fi

declare -a NEXUS_TARGETS=(
  "RealisticCraft|NEXUS_FILE_GROUP_ID_REALISTIC_CRAFT|Realistic Craft"
  "RealisticCraft_Plus|NEXUS_FILE_GROUP_ID_REALISTIC_CRAFT_PLUS|Realistic Craft Plus"
  "RealisticStorage|NEXUS_FILE_GROUP_ID_REALISTIC_STORAGE|Realistic Storage"
  "RealisticScans|NEXUS_FILE_GROUP_ID_REALISTIC_SCANS|Realistic Scans"
)

CONTENT_MODS=(RealisticCraft RealisticCraft_Plus RealisticStorage RealisticScans)

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

if [ -n "${NEXUS_MOD_VERSION:-}" ]; then
  log "Using NEXUS_MOD_VERSION override: $RELEASE_VERSION"
fi

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
  for mod_name in "${CONTENT_MODS[@]}"; do
    local zip_path="$PACKAGED_DIR/$mod_name.zip"
    if [ ! -f "$zip_path" ]; then
      fail "Expected packaged zip not found: $zip_path"
    fi
  done
}

nexus_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local extra_headers=("${@:4}")

  local args=(
    -fsSL
    -X "$method"
    -H "apikey: ${NEXUSMODS_API_KEY}"
    -H "User-Agent: RealisticSurvival-CI"
  )

  if [ -n "$body" ]; then
    args+=(-H "Content-Type: application/json" -d "$body")
  fi

  for header in "${extra_headers[@]}"; do
    args+=(-H "$header")
  done

  curl "${args[@]}" "${NEXUS_API_BASE}${path}"
}

wait_nexus_upload_available() {
  local upload_id="$1"
  for attempt in $(seq 0 59); do
    local response state
    response="$(nexus_api GET "/uploads/$upload_id")"
    state="$(python -c "import json,sys; print(json.loads(sys.argv[1])['data']['state'])" "$response")"
    log "Nexus upload $upload_id state: $state"
    if [ "$state" = "available" ]; then
      return 0
    fi
    local delay_ms=$((2000 * 3 ** attempt / 2))
    if [ "$delay_ms" -gt 30000 ]; then
      delay_ms=30000
    fi
    sleep "$(python -c "print(${delay_ms}/1000)")"
  done
  fail "Timed out waiting for Nexus upload $upload_id to become available"
}

send_nexus_mod_file() {
  local zip_path="$1"
  local group_id="$2"
  local version="$3"
  local display_name="$4"
  local description="$5"
  local file_category="${NEXUS_FILE_CATEGORY:-main}"

  if [ ! -f "$zip_path" ]; then
    fail "Nexus upload file not found: $zip_path"
  fi

  log "Starting Nexus upload for $display_name (group $group_id, version $version)"

  local file_name file_size create_body create_response upload_id part_size complete_url
  file_name="$(basename "$zip_path")"
  file_size="$(wc -c < "$zip_path" | tr -d ' ')"
  create_body="$(python -c "import json; print(json.dumps({'filename': '''$file_name''', 'size_bytes': str($file_size)}))")"
  create_response="$(nexus_api POST /uploads/multipart "$create_body")"

  upload_id="$(python -c "import json,sys; print(json.loads(sys.argv[1])['data']['id'])" "$create_response")"
  part_size="$(python -c "import json,sys; print(json.loads(sys.argv[1])['data']['part_size_bytes'])" "$create_response")"
  complete_url="$(python -c "import json,sys; print(json.loads(sys.argv[1])['data']['complete_presigned_url'])" "$create_response")"
  mapfile -t part_urls < <(python -c "
import json, sys
data = json.loads(sys.argv[1])['data']
for url in data['part_presigned_urls']:
    print(url)
" "$create_response")

  log "Created multipart upload $upload_id (${#part_urls[@]} parts)"

  local uploaded_parts=()
  local part_number=0
  for part_url in "${part_urls[@]}"; do
    part_number=$((part_number + 1))
    local offset=$(( (part_number - 1) * part_size ))
  local length
    if [ $((offset + part_size)) -gt "$file_size" ]; then
      length=$((file_size - offset))
    else
      length=$part_size
    fi

    local part_file="${TMPDIR:-/tmp}/nexus-part-${upload_id}-${part_number}.bin"
    dd if="$zip_path" of="$part_file" bs=1 skip="$offset" count="$length" status=none 2>/dev/null

    log "Uploading Nexus part $part_number/${#part_urls[@]} ($length bytes)"
    local etag
    etag="$(curl -fsSL -X PUT \
      -H "Content-Type: application/octet-stream" \
      --data-binary @"$part_file" \
      -D - -o /dev/null "$part_url" | tr -d '\r' | awk '/^[Ee][Tt][Aa][Gg]:/ {print $2}')"
    rm -f "$part_file"

    if [ -z "$etag" ]; then
      fail "Nexus part $part_number upload returned no ETag"
    fi
    etag="${etag%\"}"
    etag="${etag#\"}"
    uploaded_parts+=("$part_number|$etag")
  done

  local complete_xml
  complete_xml="$(python -c "
parts = []
import sys
for item in sys.argv[1:]:
    num, etag = item.split('|', 1)
    parts.append((int(num), etag))
parts.sort()
chunks = []
for num, etag in parts:
    chunks.append(f'  <Part>\\n    <PartNumber>{num}</PartNumber>\\n    <ETag>{etag}</ETag>\\n  </Part>')
print('<CompleteMultipartUpload>\\n' + '\\n'.join(chunks) + '\\n</CompleteMultipartUpload>')
" "${uploaded_parts[@]}")"

  curl -fsSL -X POST \
    -H "Content-Type: application/xml" \
    -d "$complete_xml" \
    "$complete_url" >/dev/null
  log "Completed Nexus multipart upload"

  nexus_api POST "/uploads/${upload_id}/finalise" >/dev/null
  wait_nexus_upload_available "$upload_id"

  local update_body published_response published_id
  update_body="$(python -c "
import json, os
body = {
    'upload_id': '''$upload_id''',
    'name': '''$display_name''',
    'version': '''$version''',
    'file_category': '''$file_category''',
}
desc = os.environ.get('NEXUS_UPLOAD_DESCRIPTION')
if desc:
    body['description'] = desc
print(json.dumps(body))
")"
  published_response="$(nexus_api POST "/mod-file-update-groups/${group_id}/versions" "$update_body")"
  published_id="$(python -c "import json,sys; print(json.loads(sys.argv[1])['data']['id'])" "$published_response")"
  log "Published Nexus file id $published_id"
}

if [ -z "${NEXUSMODS_API_KEY:-}" ]; then
  log "Nexus API key not configured; skipping upload (set NEXUSMODS_API_KEY)"
  write_output published false
  exit 0
fi

ensure_content_zips

description="${NEXUS_UPLOAD_DESCRIPTION:-}"
if [ -z "$description" ] && [ -n "${GITHUB_SHA:-}" ]; then
  description="Automated build $RELEASE_VERSION from commit $GITHUB_SHA"
elif [ -z "$description" ]; then
  description="Automated build $RELEASE_VERSION"
fi
export NEXUS_UPLOAD_DESCRIPTION="$description"

missing_groups=()
published_any=false

for target in "${NEXUS_TARGETS[@]}"; do
  IFS='|' read -r mod_name env_name display_name <<< "$target"
  group_id="${!env_name:-}"
  if [ -z "$group_id" ]; then
    missing_groups+=("$env_name")
    continue
  fi

  zip_path="$PACKAGED_DIR/${mod_name}.zip"
  send_nexus_mod_file "$zip_path" "$group_id" "$RELEASE_VERSION" "$display_name" "$description"
  published_any=true
done

if [ "${#missing_groups[@]}" -eq "${#NEXUS_TARGETS[@]}" ]; then
  log "No Nexus file group IDs configured; skipping all Nexus uploads"
  write_output published false
  exit 0
fi

if [ "${#missing_groups[@]}" -gt 0 ]; then
  fail "Missing Nexus file group secrets: $(IFS=', '; echo "${missing_groups[*]}")"
fi

write_output published "$published_any"
log "Nexus phase finished"
