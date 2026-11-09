#!/bin/bash
# Long run: usage soak.sh NAME IMAGE OPTIONS_JSON OUTDIR DURATION_S
NAME=$1 IMAGE=$2 OPTS=$3 OUT=$4 DUR=$5
mkdir -p "$OUT/snap"; cd "$(dirname "$0")"
./run-ha.sh "$NAME" "$IMAGE" "$OPTS"
CID=$(docker inspect -f '{{.Id}}' "$NAME")
CG=$(find /sys/fs/cgroup -maxdepth 3 -type d -name "*$CID*" | head -1)
T0=$(date +%s)
echo "ready_s=$(./wait-ready.sh "$NAME" 1200)" > "$OUT/ready.txt"
echo "t,mem_mib,anon_mib,file_mib,cpu_s_total,unifi,core,pg,rabbit,ulp,mongodb_state,java_heap_committed" > "$OUT/timeline.csv"
while [ $(( $(date +%s) - T0 )) -lt "$DUR" ]; do
  t=$(( $(date +%s) - T0 ))
  mem=$(( $(cat $CG/memory.current) / 1048576 ))
  anon=$(( $(awk '$1=="anon"{print $2}' $CG/memory.stat) / 1048576 ))
  file=$(( $(awk '$1=="file"{print $2}' $CG/memory.stat) / 1048576 ))
  cpu=$(awk '/usage_usec/{printf "%.1f", $2/1e6}' $CG/cpu.stat)
  svc=$(docker exec "$NAME" bash -c 'for u in unifi unifi-core postgresql@14-main rabbitmq-server ulp-go; do echo -n "$(( $(systemctl show $u -p MemoryCurrent --value) / 1048576 )),"; done; echo -n "$(systemctl show mongodb -p ActiveState --value),"; tail -1 /usr/lib/unifi/logs/gc.log | grep -oE "\([0-9]+M\)" | tail -1 | tr -d "()M"' 2>/dev/null)
  echo "$t,$mem,$anon,$file,$cpu,$svc" >> "$OUT/timeline.csv"
  if [ $(( (t / 60) % 30 )) -eq 0 ]; then
    docker exec "$NAME" bash -c 'systemd-cgtop -b -n1 --depth=2 -m --raw | head -25; journalctl --disk-usage' > "$OUT/snap/$t.txt" 2>&1
  fi
  sleep 60
done
d(){ docker exec "$NAME" bash -c "$1" > "$OUT/$2" 2>&1; }
d 'journalctl -u mongodb -u unifi-mongodb --no-pager | tail -50; systemctl status mongodb --no-pager | head -15' mongodb.txt
d 'for u in $(systemctl list-units --type=service --no-legend --plain | awk "{print \$1}"); do echo "$u $(systemctl show $u -p ActiveState,NRestarts,MemoryCurrent,CPUUsageNSec --value | tr "\n" " ")"; done' services-end.txt
d 'journalctl -b --no-pager -p err | tail -100' journal-err.txt
d 'grep -E "Pause Full|to-space" /usr/lib/unifi/logs/gc.log | tail -20; tail -3 /usr/lib/unifi/logs/gc.log' gc.txt
d 'journalctl --disk-usage' journal-size.txt
docker exec "$NAME" curl -s http://127.0.0.1:8080/status > "$OUT/network-status.json"
