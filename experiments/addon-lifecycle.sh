#!/bin/bash
# Build ha-app-tuned like Supervisor, then exercise on -> off -> on on ONE container.
set -u
cd "$(dirname "$0")/.."
OUT=${1:-out/lifecycle}; mkdir -p "$OUT"
R="$OUT/result.txt"; : > "$R"
pass(){ echo "PASS $*" | tee -a "$R"; }; fail(){ echo "FAIL $*" | tee -a "$R"; FAILED=1; }
FAILED=0
for f in Dockerfile uos-entrypoint.sh uos-tuning.sh uos-resource-report.sh; do
  cmp -s "$f" "ha-app-tuned/$f" && pass "in sync: $f" || fail "out of sync: $f"; done
docker build -q --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest -t addon-test ha-app-tuned >/dev/null || { fail build; exit 1; }
pass "build from add-on folder"
# Supervisor writes options.json from config.yaml defaults
OPTS=$(python3 -c 'import yaml,json;print(json.dumps(yaml.safe_load(open("ha-app-tuned/config.yaml"))["options"]))')
echo "$OPTS" > "$OUT/default-options.json"
SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ); experiments/run-ha.sh uos addon-test "$OPTS"
B=/tmp/ha/uos
check_state(){ # mode
  local mode=$1 t
  t=$(experiments/wait-ready.sh uos 1200) && pass "$mode: ready in ${t}s" || fail "$mode: not ready"
  sleep 150
  local java=$(docker exec uos bash -c 'tr "\0" " " < /proc/$(pgrep -o -u unifi java)/cmdline')
  local mongo=$(docker exec uos systemctl is-active mongodb)
  local st=$(docker exec uos curl -s http://127.0.0.1:8080/status)
  local failed=$(docker exec uos systemctl --failed --no-legend --plain | wc -l)
  echo "$mode java: $java" >> "$OUT/java.txt"
  echo "$st" | grep -q '"rc":"ok"' && pass "$mode: network status ok" || fail "$mode: network status $st"
  [ "$failed" = 0 ] && pass "$mode: no failed units" || fail "$mode: failed units $(docker exec uos systemctl --failed --no-legend --plain)"
  [ "$(docker exec uos curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1/)" = 200 ] && pass "$mode: UI 200" || fail "$mode: UI"
  docker logs --since "$SINCE" uos 2>&1 | grep -q "\[resources\]" && pass "$mode: resource report in log" || fail "$mode: no resource report"
  if [ "$mode" = off ]; then
    echo "$java" | grep -q "MaxRAMPercentage=70" && pass "off: stock JVM opts" || fail "off: JVM opts not stock"
    [ "$mongo" = active ] && pass "off: mongodb restored" || fail "off: mongodb $mongo"
    [ -z "$(docker exec uos bash -c 'ls /etc/systemd/system/*.d/90-uos-tuning.conf /etc/systemd/journald.conf.d/90-uos-tuning.conf /etc/systemd/system.conf.d/90-uos-tuning.conf 2>/dev/null')" ] && pass "off: no tuning drop-ins" || fail "off: drop-ins left"
    [ "$(docker exec uos systemctl is-enabled apt-daily.timer)" != masked ] && pass "off: timers unmasked" || fail "off: timers still masked"
  else
    echo "$java" | grep -q -- "-Xmx1024M" && pass "$mode: heap cap" || fail "$mode: no heap cap"
    echo "$java" | grep -q "MaxRAMPercentage" && fail "$mode: MaxRAMPercentage still present" || pass "$mode: MaxRAMPercentage removed"
    echo "$java" | grep -q "G1PeriodicGCInterval" && pass "$mode: return-memory flags" || fail "$mode: no return-memory flags"
    echo "$java" | grep -q -- "-Dunifi-os.server=true" && pass "$mode: required -D flags kept" || fail "$mode: -D flags lost"
    [ "$mongo" != active ] && pass "$mode: unused mongodb not running" || fail "$mode: mongodb running"
    [ "$(docker exec uos systemctl is-enabled apt-daily.timer)" = masked ] && pass "$mode: timers masked" || fail "$mode: timers"
    docker exec uos bash -c 'cat /proc/$(pgrep -o -u unifi java)/environ | tr "\0" "\n" | grep -q MALLOC_ARENA_MAX=2' && pass "$mode: malloc arenas" || fail "$mode: malloc env"
    docker exec uos grep -q RuntimeMaxUse=32M /etc/systemd/journald.conf.d/90-uos-tuning.conf && pass "$mode: journal cap" || fail "$mode: journal cap"
  fi
  docker exec uos bash -c 'systemctl list-timers uos-resource-report.timer --no-pager; journalctl -u uos-resource-report --no-pager | tail -5' > "$OUT/report-$mode.txt" 2>&1
  docker exec uos bash -c 'systemd-cgtop -b -n1 --depth=2 -m --raw | head -12' > "$OUT/cgtop-$mode.txt"
}
check_state on
docker logs uos 2>&1 > "$OUT/docker-logs-on.txt"
docker stop -t 120 uos >/dev/null
jq '.UOS_TUNING=false' "$B/data/options.json" > /tmp/o && sudo cp /tmp/o "$B/data/options.json"
SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ); docker start uos >/dev/null; check_state off
docker stop -t 120 uos >/dev/null
jq '.UOS_TUNING=true' "$B/data/options.json" > /tmp/o && sudo cp /tmp/o "$B/data/options.json"
SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ); docker start uos >/dev/null; check_state on2
docker logs uos 2>&1 | grep -E "tuning|Resource|heap|mongodb|journald|timers|MALLOC|\[resources\]" > "$OUT/docker-logs-summary.txt"
echo "FAILED=$FAILED" >> "$R"
exit $FAILED
