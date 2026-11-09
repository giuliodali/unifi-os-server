#!/bin/bash
# Boot the add-on image the way HA Supervisor does (options.json in /data,
# app_config at /config, caps NET_ADMIN/NET_RAW/SYS_ADMIN, apparmor off,
# private cgroup namespace) and optionally cap memory like a small HA box.
# usage: run-ha.sh NAME IMAGE OPTIONS_JSON [extra docker args...]
set -euo pipefail
NAME=$1 IMAGE=$2 OPTS=$3; shift 3
BASE=/tmp/ha/$NAME
sudo rm -rf "$BASE"; mkdir -p "$BASE/data" "$BASE/config"
echo "$OPTS" > "$BASE/data/options.json"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --security-opt apparmor=unconfined \
  --cgroupns private \
  --stop-signal SIGRTMIN+3 \
  -v "$BASE/data:/data" -v "$BASE/config:/config" \
  -e SUPERVISOR_TOKEN= \
  "$@" "$IMAGE" >/dev/null
echo "started $NAME"
