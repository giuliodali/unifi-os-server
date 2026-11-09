#!/bin/bash
# One-line resource summary per service, written to the add-on log.
# CPU % is averaged since the previous report (100% = one full core).
STATE=/run/uos-resource-report.state
SERVICES="unifi unifi-core postgresql@14-main rabbitmq-server ulp-go mongodb nginx"
now=$(date +%s%N)
declare -A prev
[ -f "$STATE" ] && while read -r k v; do prev[$k]=$v; done < "$STATE"
: > "$STATE.new"
echo "_t $now" >> "$STATE.new"
line=""
for s in $SERVICES; do
    st=$(systemctl show "$s.service" -p ActiveState --value 2>/dev/null)
    [ "$st" = active ] || continue
    mem=$(systemctl show "$s.service" -p MemoryCurrent --value)
    cpu=$(systemctl show "$s.service" -p CPUUsageNSec --value)
    echo "$s $cpu" >> "$STATE.new"
    pct="-"
    if [ -n "${prev[$s]}" ] && [ -n "${prev[_t]}" ] && [[ "$cpu" =~ ^[0-9]+$ ]]; then
        pct=$(awk -v a="${prev[$s]}" -v b="$cpu" -v x="${prev[_t]}" -v y="$now" 'BEGIN{printf "%.1f%%", (b-a)*100/(y-x)}')
    fi
    [[ "$mem" =~ ^[0-9]+$ ]] && mem="$(( mem / 1048576 ))M" || mem="?"
    line="$line ${s%%@*}=${mem}/${pct}"
done
mv "$STATE.new" "$STATE"
total=$(( $(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo 0) / 1048576 ))
heap=$(tail -1 /usr/lib/unifi/logs/gc.log 2>/dev/null | grep -oE '[0-9]+M->[0-9]+M\([0-9]+M\)' | tail -1)
echo "[resources] total=${total}M java_heap=${heap:-?}${line}"
