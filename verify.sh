#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

init_target "$@"
[[ "$(adb_shell getprop sys.boot_completed | tr -d '\r')" == 1 ]] || die "Shield is still booting"
load_package_lists
require_preserved_packages

failures=0
for package in "${DISABLE_PACKAGES[@]}"; do
  if is_installed "$package" && ! is_disabled "$package"; then
    say "FAIL: enabled: $package"
    failures=$((failures + 1))
  fi
done

if is_installed "$GAMESTREAM_PACKAGE"; then
  say "FAIL: GameStream remains installed for user 0"
  failures=$((failures + 1))
elif adb_shell pidof "$GAMESTREAM_PACKAGE" >/dev/null 2>&1; then
  say "FAIL: GameStream process remains running; reboot and verify again"
  failures=$((failures + 1))
fi

role="$(home_role_holder)"
home="$(home_component)"
if [[ "$role" != com.spocky.projengmenu || "$home" != com.spocky.projengmenu/* ]]; then
  say "FAIL: HOME role=$role resolved=$home"
  failures=$((failures + 1))
fi

if (( failures > 0 )); then die "$failures verification check(s) failed"; fi
say "PASS: Projectivy is HOME ($home)"
say "PASS: nine target packages disabled or absent; GameStream absent and not running"
say "PASS: Assistant, speech, Play services, Play Store, and OTA packages enabled"
say "Streaming apps are not changed by this profile; test playback in your own apps."
