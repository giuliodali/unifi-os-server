#!/bin/bash
# Sample container memory/CPU every INTERVAL seconds for DURATION seconds.
# Output CSV: t,mem_mib,cpu_pct(container, from cgroup usage delta)
NAME=$1 DURATION=${2:-600} INTERVAL=${3:-15} OUT=$4
CID=$(docker inspect -f '{{.Id}}' "$NAME")
CG=$(find /sys/fs/cgroup -maxdepth 3 -type d -name "*$CID*" | head -1)
echo "t,mem_mib,anon_mib,file_mib,cpu_pct" > "$OUT"
prev=$(awk '/usage_usec/{print $2}' "$CG/cpu.stat"); pt=$(date +%s%N)
for ((i=0; i<DURATION; i+=INTERVAL)); do
  sleep "$INTERVAL"
  cur=$(awk '/usage_usec/{print $2}' "$CG/cpu.stat"); ct=$(date +%s%N)
  mem=$(( $(cat "$CG/memory.current") / 1048576 ))
  anon=$(( $(awk '$1=="anon"{print $2}' "$CG/memory.stat") / 1048576 ))
  file=$(( $(awk '$1=="file"{print $2}' "$CG/memory.stat") / 1048576 ))
  cpu=$(awk -v a=$prev -v b=$cur -v x=$pt -v y=$ct 'BEGIN{printf "%.1f", (b-a)*1000*100/(y-x)}')
  echo "$((i+INTERVAL)),$mem,$anon,$file,$cpu" >> "$OUT"
  prev=$cur; pt=$ct
done
