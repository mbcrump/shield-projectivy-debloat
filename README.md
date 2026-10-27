# SHIELD + Projectivy debloat profile

Reproduce a tested, reversible NVIDIA SHIELD Android TV setup that uses
[Projectivy Launcher](https://play.google.com/store/apps/details?id=com.spocky.projengmenu)
as Home, removes unused launcher and Cast services, and **leaves streaming,
voice search, Google Play, and system update packages enabled**.

This profile was verified on `SHIELD_Android_TV` (`mdarcy`), Android 11, user 0.
The scripts stop on other devices or Android versions. They do not install
Projectivy or any streaming app. Install and open Projectivy first.

## Use

Install Android platform tools (`adb`), enable Network debugging on the Shield,
and authorize this computer on the TV. Use your Shield's own address in place of
`192.168.1.50:5555`:

```sh
adb connect 192.168.1.50:5555
./apply.sh 192.168.1.50:5555
adb -s 192.168.1.50:5555 reboot
# Reconnect after the Shield finishes booting, if needed:
adb connect 192.168.1.50:5555
./verify.sh 192.168.1.50:5555
```

`apply.sh` saves a per-device original-state snapshot in `.state/` before its
first change. Keep that folder on your computer for rollback. Rerunning
`apply.sh` uses the same snapshot and is safe after an interrupted ADB session.
`verify.sh` checks package state, the Home role and resolver, and that the
persistent GameStream process did not return after reboot. It does not test
microphone input or play video for you.

## Performance measurements

See [BENCHMARKS.md](BENCHMARKS.md) for measurements from the tested Shield and
their limitations. `benchmark.sh` is read-only and records available RAM,
running process count, GameStream process presence, and resolved Home activity
three times, at intervals of at least ten seconds. Run it after the device has
been idle for at least two minutes
following a reboot:

```sh
./benchmark.sh 192.168.1.50:5555 my-profile > my-profile.csv
```

The published "before" state was reconstructed by reversing this profile,
because no measurements were captured before the original debloat. The script
does not switch profiles or reboot the TV; the README's setup and rollback
commands provide those steps when you want to repeat the comparison.

## What the profile changes

| Package or setting | Change | Effect |
| --- | --- | --- |
| `com.spocky.projengmenu` | Set as Home role and Home activity | Projectivy launches when Home is pressed and after reboot. |
| `com.google.android.tvlauncher` | Disable for user 0 | Stops the stock launcher from winning Home resolution. |
| `com.google.android.tvrecommendations` | Disable for user 0 | Removes the old TV recommendations service; the TV notification side panel may also be affected. |
| `com.google.android.apps.mediashell` | Disable for user 0 | Disables Google Cast reception on the Shield. |
| `com.nvidia.shieldbeta` | Disable for user 0 | Stops the SHIELD Beta app. |
| `com.google.android.backdrop` | Disable for user 0 | Disables Google's Ambient screensaver. |
| `com.nvidia.nvgamecast` | Uninstall with `-k --user 0` | Stops persistent NVIDIA GameStream. The APK remains in `/system/app/NvGamecast/` and its data is kept for rollback. |
| `com.nvidia.benchmarkblocker`, `com.google.android.feedback`, `com.nvidia.stats`, `com.nvidia.feedback` | Disable for user 0 | These four were already disabled on the tested Shield; this profile includes them to reproduce its state. |

The stock launcher remained the resolved Home app on the tested Shield even
after `set-home-activity` reported success. Disabling that package made
Projectivy the resolved and resumed Home app. GameStream was marked disabled
but its persistent system process restarted after a reboot; user-level removal
followed by reboot stopped it.

## What stays enabled

- Google Assistant/voice search: `com.google.android.katniss`,
  `com.google.android.speech.pumpkin`, `com.google.android.tts`
- Google Play services and Store: `com.google.android.gms`, `com.android.vending`
- NVIDIA OTA updater: `com.nvidia.ota`
- All installed streaming apps, including Netflix, Prime Video, Plex,
  SmartTube, YouTube, VLC, and Steam Link if present
- Shield controller, Bluetooth, audio, video decoding, and DRM packages

This is a targeted debloat profile, not a full de-Google recipe. It avoids the
bulk removal of Play services, the Store, the Assistant, and media/security
components in some forum guides because those changes conflict with this
profile's streaming and voice-search goals.

## Roll back

From the same checkout, with the `.state/` snapshot still present:

```sh
adb connect 192.168.1.50:5555
./rollback.sh 192.168.1.50:5555
adb -s 192.168.1.50:5555 reboot
```

`rollback.sh` restores each package's **pre-apply** enabled state, reinstalls
the system GameStream package for user 0 when it was present before applying,
and restores the previous Home role and resolved Home component. Its source APK
is not deleted by this profile. The snapshot is retained so you can inspect
it. If you lose `.state/`, the direct commands to restore the main features
are:

```sh
adb -s 192.168.1.50:5555 shell pm enable --user 0 com.google.android.tvlauncher
adb -s 192.168.1.50:5555 shell pm enable --user 0 com.google.android.tvrecommendations
adb -s 192.168.1.50:5555 shell pm enable --user 0 com.google.android.apps.mediashell
adb -s 192.168.1.50:5555 shell pm enable --user 0 com.nvidia.shieldbeta
adb -s 192.168.1.50:5555 shell pm enable --user 0 com.google.android.backdrop
adb -s 192.168.1.50:5555 shell cmd package install-existing --user 0 com.nvidia.nvgamecast
adb -s 192.168.1.50:5555 shell pm enable --user 0 com.nvidia.nvgamecast
adb -s 192.168.1.50:5555 shell cmd role add-role-holder --user 0 android.app.role.HOME com.google.android.tvlauncher
adb -s 192.168.1.50:5555 shell cmd package set-home-activity --user 0 com.google.android.tvlauncher
```

The direct commands restore the stock launcher and features; they do not know
which packages were disabled on your own device before applying. Use the
snapshot-backed rollback for an exact reversal.

## Notes

- This uses ADB package-manager commands scoped to user 0. It does not require
  root, clear app data, factory-reset, or modify `/system` files.
- Reboot is a separate, visible step. It is required to confirm that the
  persistent GameStream process stays stopped and Projectivy starts on its own.
- Existing streaming apps are left untouched. Their availability and playback
  still depend on each app and its account; test the apps you use after setup.
- The measurements in `BENCHMARKS.md` describe memory and process footprint.
  They do not establish a change in app playback, frame rate, or UI latency.
