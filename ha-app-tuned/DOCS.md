# UniFi OS Server (tuned test)

Test build of the UniFi OS Server app with optional CPU/RAM tuning. Home Assistant
builds this app **locally** from this folder: the first install pulls the UniFi
OS Server base image (about 2 GB) and takes a few minutes.

Tuning only uses systemd drop-ins, environment files and service config. No UniFi
code or packaged files are modified. All tuning files are regenerated on every
start, so switching **Resource tuning** off and restarting gives you the stock
configuration back.

## What the tuning does

| Option | Default | Effect |
|---|---|---|
| Resource tuning | on | Master switch for everything below |
| UniFi Network max heap (MB) | 1024 | Stock lets the Java heap grow to **70% of host RAM**, because Home Assistant doesn't set memory limits on apps. This caps it. |
| Return idle Java memory | on | G1 periodic GC + native heap trim, so memory freed after spikes is returned to the host |
| Disable unused MongoDB | on | Stops the stand-alone `mongodb.service` (port 27017), which has no clients. UniFi Network runs its own MongoDB on 27117. Only applied while the stock config has `UNIFI_MONGODB_SERVICE_ENABLED=false`. |
| Journal size limit (MB) | 32 | The systemd journal lives in RAM (`/run`) and otherwise grows to about 10% of `/run` |
| Mask housekeeping timers | on | `apt-daily`, `apt-daily-upgrade`, `e2scrub_all` |
| malloc arenas | 2 | `MALLOC_ARENA_MAX` for all services, which limits glibc memory fragmentation |
| RabbitMQ scheduler threads | 0 (stock) | Available, but no measurable saving in tests |
| Extra JVM options | empty | Advanced |
| Resource report interval (min) | 30 | Logs one `[resources]` line per interval with memory/CPU per service. Works with tuning on **or off**. |

## Comparing on your own install

1. Under **Settings → Devices & services → Home Assistant Supervisor**, open this app's
   device and enable its **CPU percent** and **Memory percent** sensors.
2. Run for a day with **Resource tuning** off, then a day with it on (same version).
3. Compare the history graphs, and the `[resources]` lines in the app log.

## Moving your existing data to this test app

This app has its own config folder (`addon_configs/<repo-hash>_unifi_os_server_tuned`),
separate from the original app. To test with your real configuration:

1. Take a backup of the original app, then stop it (both apps use the same ports, and the
   databases must not be running while you copy).
2. Install this app but **don't start it** yet. Start and stop it once if the folder doesn't appear.
3. Copy the *contents* of the original app's `addon_configs/..._unifi_os_server` folder into
   this app's folder, replacing what's there. Copy **as root from an SSH session, preserving
   ownership** (for example `cp -a /addon_configs/<old>/. /addon_configs/<new>/`). Don't copy over
   Samba: it loses Linux file owners and permissions, and MongoDB/PostgreSQL may then fail to start.
4. Start this app. To go back, stop it and start the original again. Its data is untouched.

Alternatively, take a backup in UniFi OS (**Settings → Backups**) and restore it in this app.
