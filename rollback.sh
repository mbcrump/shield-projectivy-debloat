#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

init_target "$@"
[[ -f "$STATE_FILE" ]] || die "No original-state snapshot at $STATE_FILE"

snapshot_version="$(awk -F '\t' '$1 == "version" {print $2; exit}' "$STATE_FILE")"
snapshot_target="$(awk -F '\t' '$1 == "target" {print $2; exit}' "$STATE_FILE")"
[[ "$snapshot_version" == 1 && "$snapshot_target" == "$TARGET" ]] ||
  die "Snapshot version or target does not match"

original_role="$(awk -F '\t' '$1 == "role" {print $2; exit}' "$STATE_FILE")"
original_home="$(awk -F '\t' '$1 == "home" {print $2; exit}' "$STATE_FILE")"

while IFS=$'\t' read -r kind package installed disabled; do
  [[ "$kind" == package ]] || continue
  [[ "$installed" == 1 ]] || continue
  if [[ "$package" == "$GAMESTREAM_PACKAGE" ]]; then
    adb_shell cmd package install-existing --user 0 "$package"
  fi
  if [[ "$disabled" == 1 ]]; then
    adb_shell pm disable-user --user 0 "$package"
  else
    adb_shell pm enable --user 0 "$package"
  fi
done < "$STATE_FILE"

if [[ -n "$original_role" ]]; then
  if ! adb_shell cmd role add-role-holder --user 0 android.app.role.HOME "$original_role"; then
    [[ "$(home_role_holder)" == "$original_role" ]] || die "Could not restore HOME role"
  fi
else
  adb_shell cmd role clear-role-holders --user 0 android.app.role.HOME
fi
if [[ -n "$original_home" && "$original_home" == */* ]]; then
  adb_shell cmd package set-home-activity --user 0 "$original_home"
fi

say "Rollback commands completed. Reboot and check HOME and apps."
say "Original-state snapshot retained at $STATE_FILE"
