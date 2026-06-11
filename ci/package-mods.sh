#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ci/fetch-sn2-df-release.sh
source "$SCRIPT_DIR/fetch-sn2-df-release.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$REPO_ROOT/Source"
PACKAGED_DIR="$REPO_ROOT/Packaged"
RC_MODS="$PACKAGED_DIR/RealisticCraft/Subnautica2/Binaries/Win64/ue4ss/Mods"
RCP_MODS="$PACKAGED_DIR/RealisticCraft_Plus/Subnautica2/Binaries/Win64/ue4ss/Mods"
RS_SCAN_MODS="$PACKAGED_DIR/RealisticScans/Subnautica2/Binaries/Win64/ue4ss/Mods"
MOD_ROOTS=("$RC_MODS" "$RCP_MODS" "$RS_SCAN_MODS")
LICENSE_SOURCE="$REPO_ROOT/Licence/license"
SN2_DF_PACKAGED_MOD="$PACKAGED_DIR/SN2-DF/Subnautica2/Binaries/Win64/ue4ss/Mods/SN2-DF"
VERSION_FILE="$REPO_ROOT/ci/MOD_VERSION"
CONTENT_RELEASE_MODS=(RealisticCraft RealisticCraft_Plus RealisticStorage RealisticScans)
RETOC_VERSION="${RETOC_VERSION:-v0.1.4}"
RETOC_EXE=""

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

test_mod_version_format() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]
}

get_mod_release_version() {
  if [ -n "${NEXUS_MOD_VERSION:-}" ]; then
    if ! test_mod_version_format "$NEXUS_MOD_VERSION"; then
      fail "NEXUS_MOD_VERSION must be major.minor (e.g. 2.0); got: $NEXUS_MOD_VERSION"
    fi
    echo "$NEXUS_MOD_VERSION"
    return
  fi

  if [ -f "$VERSION_FILE" ]; then
    local from_file
    from_file="$(tr -d '\r\n' < "$VERSION_FILE")"
    if ! test_mod_version_format "$from_file"; then
      fail "Invalid ci/MOD_VERSION format (expected major.minor e.g. 2.0): $from_file"
    fi
    echo "$from_file"
    return
  fi

  echo "2.0"
}

ensure_directory() {
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
    log "Created directory: $1"
  fi
}

ensure_retoc() {
  if [ -n "${RETOC_PATH:-}" ] && [ -f "$RETOC_PATH" ]; then
    RETOC_EXE="$RETOC_PATH"
    log "Using retoc from RETOC_PATH: $RETOC_EXE"
    return
  fi

  local candidates=(
    "$REPO_ROOT/tools/retoc/retoc.exe"
    "${USERPROFILE:-}/scoop/shims/retoc.exe"
  )

  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      RETOC_EXE="$candidate"
      log "Using retoc: $RETOC_EXE"
      return
    fi
  done

  if command -v retoc >/dev/null 2>&1; then
    RETOC_EXE="$(command -v retoc)"
    log "Using retoc on PATH: $RETOC_EXE"
    return
  fi

  local tools_dir="$REPO_ROOT/tools/retoc"
  ensure_directory "$tools_dir"
  local zip_path="${TMPDIR:-/tmp}/retoc-${RETOC_VERSION}-win64.zip"
  local url="https://github.com/trumank/retoc/releases/download/${RETOC_VERSION}/retoc-x86_64-pc-windows-msvc.zip"
  log "Downloading retoc $RETOC_VERSION..."
  curl -fsSL "$url" -o "$zip_path"
  unzip -q -o "$zip_path" -d "$tools_dir"
  rm -f "$zip_path"

  RETOC_EXE="$(find "$tools_dir" -name 'retoc.exe' -type f | head -1)"
  if [ -z "$RETOC_EXE" ]; then
    fail "retoc.exe not found after extracting $url"
  fi
  log "Installed retoc to $RETOC_EXE"
}

invoke_retoc_to_zen() {
  local source_path="$1"
  local target_utoc="$2"
  local label="$3"

  if [ ! -e "$source_path" ]; then
    fail "retoc source not found for ${label}: $source_path"
  fi

  ensure_directory "$(dirname "$target_utoc")"
  log "retoc to-zen $label"
  log "  source: $source_path"
  log "  target: $target_utoc"
  "$RETOC_EXE" to-zen "$source_path" "$target_utoc" --version UE5_6
}

ensure_enabled_txt() {
  : > "$1/enabled.txt"
}

install_sn2_df_from_github_release() {
  if [ "${SN2_DF_USE_LOCAL_BUILD:-}" = "1" ]; then
    local dll="$SN2_DF_PACKAGED_MOD/dlls/main.dll"
    if [ ! -f "$dll" ]; then
      fail "SN2_DF_USE_LOCAL_BUILD=1 but Packaged/SN2-DF/dlls/main.dll is missing"
    fi
    log "Using local SN2-DF build at $dll"
    return
  fi

  install_sn2_df_from_release "$SN2_DF_PACKAGED_MOD" "$LICENSE_SOURCE"
}

remove_stale_loader_mods() {
  log "Removing stale nested SN2-DF loader folders from packaged mods..."
  for mod_root in "${MOD_ROOTS[@]}"; do
    local stale="$mod_root/SN2-DF"
    if [ -d "$stale" ]; then
      rm -rf "$stale"
      log "Removed $stale"
    fi
  done
}

ensure_packaged_sn2_df() {
  local mod_name="$1"
  local sdf="$PACKAGED_DIR/$mod_name/Subnautica2/Binaries/Win64/ue4ss/Mods/$mod_name/SN2-DF"
  if [ ! -d "$sdf" ]; then
    fail "Packaged SN2-DF not found for ${mod_name}: $sdf"
  fi
  log "Found packaged SN2-DF for $mod_name"
}

install_realistic_survival_license() {
  local src="$REPO_ROOT/LICENSE"
  local dst="$RC_MODS/RealisticCraft/LICENSE"
  if [ ! -f "$src" ]; then
    fail "Realistic Survival LICENSE not found: $src"
  fi
  cp -f "$src" "$dst"
  log "Installed Realistic Survival LICENSE at $dst"
}

cleanup_realistic_scans() {
  local target_root="$RS_SCAN_MODS/RealisticScans"
  ensure_enabled_txt "$target_root"
  for legacy in Scripts Blueprints; do
    local path="$target_root/$legacy"
    if [ -e "$path" ]; then
      rm -rf "$path"
      log "Removed legacy RealisticScans/$legacy"
    fi
  done
}

prepare_packaged_mods() {
  install_realistic_survival_license

  for name in RealisticCraft RealisticCraft_Plus RealisticScans; do
    ensure_packaged_sn2_df "$name"
  done

  for mod_root in \
    "$RC_MODS/RealisticCraft" \
    "$RCP_MODS/RealisticCraft_Plus" \
    "$RS_SCAN_MODS/RealisticScans"; do
    ensure_enabled_txt "$mod_root"
  done

  local misplaced="$RC_MODS/RealisticCraft/Builder.toml"
  if [ -f "$misplaced" ]; then
    rm -f "$misplaced"
    log "Removed misplaced RealisticCraft/Builder.toml"
  fi

  cleanup_realistic_scans
}

build_content_paks() {
  ensure_directory "$PACKAGED_DIR/RealisticCraft/Subnautica2/Content/Paks/~mods/RealisticCraft"
  ensure_directory "$PACKAGED_DIR/RealisticCraft_Plus/Subnautica2/Content/Paks/~mods/RealisticCraft_Plus"

  invoke_retoc_to_zen \
    "$SOURCE/RealisticCraft_Main" \
    "$PACKAGED_DIR/RealisticCraft/Subnautica2/Content/Paks/~mods/RealisticCraft/RealisticCraft_P.utoc" \
    RealisticCraft_Main

  invoke_retoc_to_zen \
    "$SOURCE/RealisticCraft_StringData" \
    "$PACKAGED_DIR/RealisticCraft/Subnautica2/Content/Paks/~mods/RealisticCraft/Descriptions_P.utoc" \
    RealisticCraft_StringData

  invoke_retoc_to_zen \
    "$SOURCE/RealisticCraft_Items" \
    "$PACKAGED_DIR/RealisticCraft_Plus/Subnautica2/Content/Paks/~mods/RealisticCraft_Plus/ExtraItems_P.utoc" \
    RealisticCraft_Items
}

new_mod_zip() {
  local mod_name="$1"
  local src_dir="$PACKAGED_DIR/$mod_name/Subnautica2"
  local zip_file="$PACKAGED_DIR/$mod_name.zip"

  if [ ! -d "$src_dir" ]; then
    fail "Cannot zip ${mod_name}; missing $src_dir"
  fi

  rm -f "$zip_file"
  log "Zipping $mod_name -> $zip_file"
  (cd "$PACKAGED_DIR/$mod_name" && tar -a -c -f "../$mod_name.zip" Subnautica2)
  local size
  size="$(wc -c < "$zip_file" | tr -d ' ')"
  log "Created $zip_file ($size bytes)"
  echo "$zip_file"
}

if [ ! -d "$PACKAGED_DIR" ]; then
  fail "Packaged directory not found: $PACKAGED_DIR"
fi
if [ ! -d "$SOURCE" ]; then
  fail "Source directory not found: $SOURCE"
fi

ensure_retoc
install_sn2_df_from_github_release
remove_stale_loader_mods
prepare_packaged_mods

if [ "${SKIP_PAK_BUILD:-}" != "true" ]; then
  build_content_paks
else
  log "Skipping pak build (SKIP_PAK_BUILD=true)"
fi

content_zip_files=()
for mod_name in "${CONTENT_RELEASE_MODS[@]}"; do
  content_zip_files+=("$(new_mod_zip "$mod_name")")
done

sdf_dll="$SN2_DF_PACKAGED_MOD/dlls/main.dll"
if [ ! -f "$sdf_dll" ]; then
  fail "SN2-DF loader not installed at $sdf_dll"
fi
new_mod_zip SN2-DF >/dev/null
log "Built SN2-DF.zip from Subnautica2Mods release (not published to Nexus or GitHub Releases)"

release_version="$(get_mod_release_version)"
write_output release_version "$release_version"
write_output content_zip_count "${#content_zip_files[@]}"
log "Package phase finished"
