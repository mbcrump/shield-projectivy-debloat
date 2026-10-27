#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

[[ $# -eq 2 ]] || die "Usage: $0 IP:5555 LABEL"
label="$2"
[[ "$label" =~ ^[A-Za-z0-9_-]+$ ]] || die "LABEL must contain only letters, digits, _ or -"
init_target "$1"

read_device() {
  local attempt output
  for attempt in 1 2 3 4 5; do
    if output="$(adb_shell "$@" 2>/dev/null)"; then
      printf '%s\n' "$output"
      return 0
    fi
    adb disconnect "$TARGET" >/dev/null 2>&1 || true
    adb connect "$TARGET" >/dev/null 2>&1 || true
    sleep 2
  done
  die "ADB did not respond after five attempts"
}

printf 'label,sample,uptime_s,mem_available_kib,process_count,gamecast_running,home_component\n'
for sample in 1 2 3; do
  uptime="$(read_device cat /proc/uptime | awk '{print $1}')"
  available="$(read_device cat /proc/meminfo | awk '$1 == "MemAvailable:" {print $2; exit}')"
  process_list="$(read_device ps -A)"
  processes="$(printf '%s\n' "$process_list" | awk 'NR > 1 {n++} END {print n+0}')"
  if printf '%s\n' "$process_list" | grep -Fq "$GAMESTREAM_PACKAGE"; then gamecast=1; else gamecast=0; fi
  home="$(read_device cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tr -d '\r' | tail -n 1)"
  [[ "$uptime" =~ ^[0-9]+([.][0-9]+)?$ && "$available" =~ ^[0-9]+$ && "$processes" =~ ^[0-9]+$ ]] ||
    die "Could not parse device metrics"
  [[ "$home" == */* ]] || die "Could not resolve Home activity"
  printf '%s,%s,%s,%s,%s,%s,%s\n' "$label" "$sample" "$uptime" "$available" "$processes" "$gamecast" "$home"
  if [[ "$sample" -lt 3 ]]; then sleep 10; fi
done
