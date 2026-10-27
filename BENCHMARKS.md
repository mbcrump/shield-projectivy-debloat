# Performance measurements on the tested SHIELD

These are measurements of **memory and process footprint**, not a measured
improvement in playback speed or UI responsiveness. There was no performance
capture before the original debloat. On 2026-10-27, the earlier configuration
was **reconstructed** on the same `mdarcy` SHIELD (Android 11, user 0), measured,
then the Projectivy profile was reapplied and measured. The TV was rebooted once
for each configuration.

## Result

The first samples were taken at similar times after boot: 187 seconds for the
reconstructed baseline and 196 seconds for the Projectivy profile.

| Metric | Reconstructed baseline | Projectivy profile | Difference |
| --- | ---: | ---: | ---: |
| Available RAM (`/proc/meminfo`, `MemAvailable`) | 1,035,036 KiB | 1,202,528 KiB | **+163.6 MiB** |
| Running processes (`ps -A`) | 338 | 334 | **4 fewer** |
| GameStream process | Running | Absent | Stopped |
| Resolved Home | Stock TV launcher | Projectivy | Projectivy |

The three samples from each boot are in
[the raw CSV](benchmarks/mdarcy-android11-2026-10-27.csv). Available RAM ranged
from 1,026,148 to 1,035,036 KiB in the baseline and 1,188,600 to 1,202,528
KiB with this profile. Process count was 338 in all baseline samples and
322–334 with this profile. Sampling took longer than planned because the
network ADB connection intermittently dropped and had to reconnect; the CSV
includes device uptime for each observation.

## Method

1. Reconstructed the earlier state by re-enabling the stock TV launcher,
   SHIELD Beta, Google Cast receiver, TV recommendations, and Google Backdrop;
   reinstalling the system GameStream package for user 0; and selecting the
   stock launcher as Home. The four packages that were disabled before this
   profile was assembled remained disabled.
2. Rebooted and ran `benchmark.sh` while the TV sat at Home.
3. Ran `apply.sh`, rebooted, confirmed Projectivy was Home and GameStream was
   absent, and ran the same `benchmark.sh` command at a similar post-boot age.
4. Recorded three samples per state. Each sample reads `MemAvailable`, counts
   lines in `ps -A` after its header, checks for the GameStream process, and
   resolves Home. The script is read-only.

`MemAvailable` estimates memory that can be made available without swapping;
it varies with caches and background app activity. A process count does not
measure CPU use. This is one boot per state with three observations from that
boot, so it cannot establish typical boot time, launch speed, frame rate,
streaming quality, or a statistically reliable performance gain. The comparison
does show that this profile left more available RAM in this run and stopped
the GameStream process.

To collect your own observations, reboot each configuration, wait at least two
minutes at Home, then run:

```sh
./benchmark.sh 192.168.1.50:5555 before > before.csv
./benchmark.sh 192.168.1.50:5555 after > after.csv
```

Use the appropriate command only while the matching configuration is active.
The main README documents applying and rolling back the profile. Keep the TV
idle and use similar post-boot times when comparing your CSV files.
