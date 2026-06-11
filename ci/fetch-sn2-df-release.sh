#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

get_sn2_df_release_config() {
  local default_repo="AMcilraith/Subnautica2Mods"
  local tag="latest"
  local repo="$default_repo"

  if [ -n "${SN2_DF_RELEASE:-}" ]; then
    tag="${SN2_DF_RELEASE//[[:space:]]/}"
  elif [ -n "${SDF_RELEASE:-}" ]; then
    tag="${SDF_RELEASE//[[:space:]]/}"
  elif [ -n "${SN2_DF_RELEASE_TAG:-}" ]; then
    tag="${SN2_DF_RELEASE_TAG//[[:space:]]/}"
  fi

  if [ -z "$tag" ]; then
    tag="latest"
  fi

  if [ -n "${SN2_DF_RELEASE_REPO:-}" ]; then
    repo="${SN2_DF_RELEASE_REPO//[[:space:]]/}"
  fi

  echo "$repo|$tag"
}

parse_release_field() {
  local release_json="$1"
  local field="$2"
  python -c "import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]])" "$release_json" "$field"
}

fetch_release_json() {
  local repo="$1"
  local tag="$2"
  local uri
  local headers=(-H "Accept: application/vnd.github+json")
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    headers+=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi

  if [ "$tag" = "latest" ]; then
    uri="https://api.github.com/repos/$repo/releases/latest"
  else
    local encoded_tag
    encoded_tag="$(python -c "import urllib.parse; print(urllib.parse.quote('''$tag''', safe=''))")"
    uri="https://api.github.com/repos/$repo/releases/tags/$encoded_tag"
  fi

  local response
  if ! response="$(curl -fsSL "${headers[@]}" "$uri")"; then
    echo "Failed to fetch SN2-DF release metadata from $uri (repo=$repo, tag=$tag)." >&2
    echo "Publish a release at https://github.com/$repo/releases or set vars.SN2_DF_RELEASE / SN2_DF_RELEASE_TAG to a valid tag." >&2
    exit 1
  fi

  if ! python -c "import json,sys; json.loads(sys.argv[1])" "$response" >/dev/null 2>&1; then
    echo "GitHub API returned non-JSON for $uri (repo=$repo, tag=$tag)." >&2
    echo "Response preview: $(printf '%.200s' "$response")" >&2
    exit 1
  fi

  echo "$response"
}

select_asset_name() {
  python -c "
import json, sys
release = json.load(sys.stdin)
assets = release.get('assets') or []
tag = release.get('tag_name', '')
for preferred in ('SN2-DF.zip', 'SDF.zip', 'main.dll'):
    for asset in assets:
        if asset.get('name') == preferred:
            print(json.dumps(asset))
            sys.exit(0)
names = ', '.join(a.get('name', '') for a in assets)
print(f\"Release '{tag}' is missing SN2-DF.zip, SDF.zip, or main.dll. Found: {names}\", file=sys.stderr)
sys.exit(1)
"
}

download_asset() {
  local asset_json="$1"
  local destination="$2"
  local parent
  parent="$(dirname "$destination")"
  mkdir -p "$parent"
  rm -f "$destination"

  python -c "
import json, os, subprocess, sys
asset = json.loads(sys.argv[1])
dest = sys.argv[2]
url = asset.get('browser_download_url')
headers = []
token = os.environ.get('GITHUB_TOKEN')
if not url:
    url = asset.get('url')
    headers = ['-H', 'Accept: application/octet-stream']
    if token:
        headers.extend(['-H', f'Authorization: Bearer {token}'])
elif token:
    headers = ['-H', f'Authorization: Bearer {token}']
cmd = ['curl', '-fsSL', *headers, '-o', dest, url]
try:
    subprocess.check_call(cmd)
except subprocess.CalledProcessError as exc:
    print(f'Failed to download SN2-DF asset from {url}: curl exited {exc.returncode}', file=sys.stderr)
    sys.exit(exc.returncode)
" "$asset_json" "$destination"
}

validate_downloaded_asset() {
  local path="$1"
  local asset_name="$2"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ "$asset_name" == *.zip ]]; then
    python "$script_dir/archive.py" validate "$path" "$asset_name" || {
      echo "Download failed: $path is not a valid zip or tar archive." >&2
      return 1
    }
    return 0
  fi

  if [[ "$asset_name" == *.dll ]]; then
    python -c "
import os, sys
path = sys.argv[1]
if not os.path.isfile(path) or os.path.getsize(path) < 1:
    print(f'Download failed: missing or empty DLL at {path}', file=sys.stderr)
    sys.exit(1)
with open(path, 'rb') as handle:
    if handle.read(2) != b'MZ':
        print(f'Download failed: {path} is not a valid PE DLL.', file=sys.stderr)
        sys.exit(1)
" "$path"
    return
  fi

  echo "Download failed: unsupported asset type: $asset_name" >&2
  return 1
}

install_sn2_df_mod_layout_from_dll() {
  local mod_dir="$1"
  local dll_path="$2"
  local license_source="$3"

  mkdir -p "$mod_dir/dlls"
  cp -f "$dll_path" "$mod_dir/dlls/main.dll"
  find "$mod_dir" -maxdepth 1 -type f -name 'LICENSE_*.txt' -delete

  if [ ! -d "$license_source" ]; then
    echo "SN2-DF license source not found: $license_source" >&2
    exit 1
  fi

  mkdir -p "$mod_dir/license"
  cp -R "$license_source/." "$mod_dir/license/"
  : > "$mod_dir/enabled.txt"
}

install_sn2_df_from_release() {
  local packaged_mod_dir="$1"
  local license_source="$2"

  IFS='|' read -r repo tag < <(get_sn2_df_release_config)
  local release_json asset_json asset_name release_tag
  release_json="$(fetch_release_json "$repo" "$tag")"
  release_tag="$(parse_release_field "$release_json" "tag_name")"
  if [ -z "$release_tag" ]; then
    echo "GitHub release response is missing tag_name (repo=$repo, requested tag=$tag)." >&2
    exit 1
  fi

  asset_json="$(printf '%s' "$release_json" | select_asset_name)"
  asset_name="$(parse_release_field "$asset_json" "name")"

  log "Installing SN2-DF from $repo release $release_tag ($asset_name)..."

  local temp_root
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/sn2-df-release-XXXXXX")"
  # Capture path in the trap string; RETURN runs after locals are unset under set -u.
  trap 'rm -rf "'"$temp_root"'"' RETURN

  local download_path="$temp_root/$asset_name"
  download_asset "$asset_json" "$download_path"
  validate_downloaded_asset "$download_path" "$asset_name"

  if [[ "$asset_name" == *.zip ]]; then
    local extract_dir="$temp_root/extract"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    mkdir -p "$extract_dir"
    python "$script_dir/archive.py" extract "$download_path" "$extract_dir"

    local subnautica_root
    subnautica_root="$(find "$extract_dir" -type d -name Subnautica2 | head -1)"
    if [ -z "$subnautica_root" ]; then
      echo "$asset_name does not contain a Subnautica2/ folder." >&2
      exit 1
    fi

    local packaged_root="$packaged_mod_dir"
    local packaged_base=""
    while [ -n "$packaged_root" ]; do
      packaged_base="$(basename "$packaged_root")"
      if [ "$packaged_base" = "SN2-DF" ] || [ "$packaged_base" = "SDF" ]; then
        break
      fi
      packaged_root="$(dirname "$packaged_root")"
    done
    if [ -z "$packaged_root" ] || { [ "$packaged_base" != "SN2-DF" ] && [ "$packaged_base" != "SDF" ]; }; then
      echo "Could not resolve Packaged/SN2-DF or Packaged/SDF root from $packaged_mod_dir" >&2
      exit 1
    fi

    local target_subnautica="$packaged_root/Subnautica2"
    rm -rf "$target_subnautica"
    cp -R "$subnautica_root" "$target_subnautica"

    local mods_dir
    mods_dir="$(dirname "$packaged_mod_dir")"
    if [ -d "$mods_dir/SN2-DF" ] && [ ! -d "$mods_dir/SDF" ]; then
      mv "$mods_dir/SN2-DF" "$mods_dir/SDF"
      log "Renamed release mod folder $mods_dir/SN2-DF -> SDF"
    elif [ -d "$mods_dir/SN2-DF" ] && [ -d "$mods_dir/SDF" ]; then
      rm -rf "$mods_dir/SN2-DF"
      log "Removed duplicate release mod folder $mods_dir/SN2-DF (keeping SDF)"
    fi

    local dll_path="$packaged_mod_dir/dlls/main.dll"
    if [ ! -f "$dll_path" ]; then
      echo "$asset_name installed but main.dll is missing at $dll_path" >&2
      exit 1
    fi

    mkdir -p "$packaged_mod_dir/license"
    cp -R "$license_source/." "$packaged_mod_dir/license/"
    : > "$packaged_mod_dir/enabled.txt"
  else
    install_sn2_df_mod_layout_from_dll "$packaged_mod_dir" "$download_path" "$license_source"
  fi

  cat > "$packaged_mod_dir/SN2-DF_RELEASE.txt" <<EOF
repo=$repo
tag=$release_tag
asset=$asset_name
installed=$(date -Iseconds)
EOF

  log "SN2-DF installed to $packaged_mod_dir"
}
