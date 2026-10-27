#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAMESTREAM_PACKAGE=com.nvidia.nvgamecast

# This list reproduces the disabled packages on the tested Shield. The last four
# were already disabled before this profile was assembled.
DISABLE_PACKAGES=(
  com.google.android.tvlauncher
  com.nvidia.shieldbeta
  com.google.android.apps.mediashell
  com.google.android.tvrecommendations
  com.google.android.backdrop
  com.nvidia.benchmarkblocker
  com.google.android.feedback
  com.nvidia.stats
  com.nvidia.feedback
)

# These packages are never changed. Their presence is checked before applying.
REQUIRED_PACKAGES=(
  com.spocky.projengmenu
  com.google.android.katniss
  com.google.android.speech.pumpkin
  com.google.android.tts
  com.google.android.gms
  com.android.vending
  com.nvidia.ota
)

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

init_target() {
  [[ $# -eq 1 && -n "$1" ]] || die "Usage: $0 IP:5555"
  TARGET="$1"
  command -v adb >/dev/null 2>&1 || die "adb is required"
  [[ "$(adb -s "$TARGET" get-state 2>/dev/null)" == device ]] ||
    die "ADB target $TARGET is not connected and authorized; run: adb connect $TARGET"

  local model android_version user_id
  model="$(adb_shell getprop ro.product.device | tr -d '\r')"
  android_version="$(adb_shell getprop ro.build.version.release | tr -d '\r')"
  user_id="$(adb_shell am get-current-user | tr -d '\r')"
  [[ "$model" == mdarcy && "$android_version" == 11 && "$user_id" == 0 ]] ||
    die "This profile is tested only on mdarcy / Android 11 / user 0 (found: $model / $android_version / $user_id)"

  local safe_target
  safe_target="$(printf '%s' "$TARGET" | tr -c 'A-Za-z0-9_.-' '_')"
  STATE_DIR="${SHIELD_STATE_DIR:-$ROOT_DIR/.state}"
  STATE_FILE="$STATE_DIR/$safe_target.tsv"
}

adb_shell() { adb -s "$TARGET" shell "$@"; }

load_package_lists() {
  INSTALLED_PACKAGES="$(adb_shell pm list packages --user 0 | tr -d '\r')"
  DISABLED_PACKAGES="$(adb_shell pm list packages -d --user 0 | tr -d '\r')"
}

has_package_line() {
  local list="$1" package="$2"
  printf '%s\n' "$list" | grep -Fqx "package:$package"
}

is_installed() { has_package_line "$INSTALLED_PACKAGES" "$1"; }
is_disabled() { has_package_line "$DISABLED_PACKAGES" "$1"; }

home_role_holder() {
  adb_shell dumpsys role | tr -d '\r' | awk '
    /name=android.app.role.HOME/ {
      getline
      if ($1 ~ /^holders=/) { sub(/^holders=/, "", $1); print $1 }
      exit
    }'
}

home_component() {
  adb_shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN -c android.intent.category.HOME |
    tr -d '\r' | tail -n 1
}

require_preserved_packages() {
  local package
  for package in "${REQUIRED_PACKAGES[@]}"; do
    is_installed "$package" && ! is_disabled "$package" ||
      die "Required package is missing or disabled: $package"
  done
}
