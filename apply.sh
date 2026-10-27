#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

init_target "$@"
load_package_lists
require_preserved_packages

mkdir -p "$STATE_DIR"
if [[ ! -e "$STATE_FILE" ]]; then
  temp_file="$(mktemp "$STATE_FILE.XXXXXX")"
  trap 'rm -f "$temp_file"' EXIT
  {
    printf 'version\t1\n'
    printf 'target\t%s\n' "$TARGET"
    printf 'role\t%s\n' "$(home_role_holder)"
    printf 'home\t%s\n' "$(home_component)"
    for package in "${DISABLE_PACKAGES[@]}" "$GAMESTREAM_PACKAGE"; do
      installed=0; disabled=0
      if is_installed "$package"; then installed=1; fi
      if is_disabled "$package"; then disabled=1; fi
      printf 'package\t%s\t%s\t%s\n' "$package" "$installed" "$disabled"
    done
  } > "$temp_file"
  mv "$temp_file" "$STATE_FILE"
  trap - EXIT
  say "Saved original state to $STATE_FILE"
else
  snapshot_version="$(awk -F '\t' '$1 == "version" {print $2; exit}' "$STATE_FILE")"
  snapshot_target="$(awk -F '\t' '$1 == "target" {print $2; exit}' "$STATE_FILE")"
  [[ "$snapshot_version" == 1 && "$snapshot_target" == "$TARGET" ]] ||
    die "Existing snapshot version or target does not match"
  say "Using existing original-state snapshot: $STATE_FILE"
fi

# A successful set-home-activity alone did not beat the stock launcher on the
# tested Shield. Set the role, then disable the competing stock launcher.
if ! adb_shell cmd role add-role-holder --user 0 android.app.role.HOME com.spocky.projengmenu; then
  [[ "$(home_role_holder)" == com.spocky.projengmenu ]] || die "Could not set Projectivy HOME role"
fi
adb_shell cmd package set-home-activity --user 0 com.spocky.projengmenu

for package in "${DISABLE_PACKAGES[@]}"; do
  if ! is_installed "$package"; then
    say "Not installed; skipping $package"
  elif is_disabled "$package"; then
    say "Already disabled: $package"
  else
    adb_shell pm disable-user --user 0 "$package"
  fi
done

if is_installed "$GAMESTREAM_PACKAGE"; then
  adb_shell pm uninstall -k --user 0 "$GAMESTREAM_PACKAGE"
else
  say "Already absent for user 0: $GAMESTREAM_PACKAGE"
fi

say "Apply complete. Reboot the Shield, then run ./verify.sh $TARGET"
say "Rollback snapshot: $STATE_FILE"
