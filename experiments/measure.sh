#!/bin/bash
# Full measurement of one variant. usage: measure.sh NAME IMAGE OPTIONS_JSON OUTDIR
NAME=$1 IMAGE=$2 OPTS=$3 OUT=$4
mkdir -p "$OUT"; cd "$(dirname "$0")"
SETTLE=${SETTLE:-600} WINDOW=${WINDOW:-1200}
./run-ha.sh "$NAME" "$IMAGE" "$OPTS"
CID=$(docker inspect -f '{{.Id}}' "$NAME")
CG=$(find /sys/fs/cgroup -maxdepth 3 -type d -name "*$CID*" | head -1)
T0=$(date +%s)
READY=$(./wait-ready.sh "$NAME" 1200)
CPU_READY=$(awk '/usage_usec/{printf "%.1f", $2/1e6}' "$CG/cpu.stat")
rem=$(( SETTLE - ($(date +%s) - T0) )); [ $rem -gt 0 ] && sleep $rem
CPU_SETTLED=$(awk '/usage_usec/{printf "%.1f", $2/1e6}' "$CG/cpu.stat")
./sample.sh "$NAME" "$WINDOW" 15 "$OUT/samples.csv"
d(){ docker exec "$NAME" bash -c "$1" > "$OUT/$2" 2>&1; }
d 'systemd-cgtop -b -n 1 --depth=3 -m --raw' cgtop-mem.txt
d 'for u in $(systemctl list-units --type=service --state=running --no-legend --plain | awk "{print \$1}"); do printf "%s %s %s\n" $u $(systemctl show $u -p MemoryCurrent --value) $(systemctl show $u -p CPUUsageNSec --value); done | sort -k2 -nr' services.txt
d 'ps -eo pid,rss,pcpu,cputime,args --sort=-rss | cut -c1-400 | head -40' ps.txt
d 'tr "\0" " " < /proc/$(pgrep -f ace.jar)/cmdline' java-cmdline.txt
d 'tail -5 /usr/lib/unifi/logs/gc.log; grep -c Pause /usr/lib/unifi/logs/gc.log' gc-tail.txt
d 'journalctl --disk-usage; du -sh /run/log/journal; journalctl -o cat --since "-10min" | wc -c' journal.txt
d 'journalctl -b --no-pager | grep -iE "error|fail|oom|killed|outofmemory" | grep -v "^$" | tail -80' journal-errors.txt
d 'cat /etc/systemd/system/*.service.d/90-uos-tuning.conf /etc/uos-tuning/* /etc/systemd/journald.conf.d/* /etc/systemd/system.conf.d/* /etc/postgresql/14/main/conf.d/* 2>/dev/null; ls -la /etc/systemd/system/ | grep -E "timer|null"; systemctl is-enabled mongodb' tuning-files.txt
# health
H=$OUT/health.txt
{
  echo "network_status=$(docker exec $NAME curl -s http://127.0.0.1:8080/status)"
  echo "core_https=$(docker exec $NAME curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:443/)"
  echo "core_api=$(docker exec $NAME curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:443/api/system)"
  echo "failed_units=$(docker exec $NAME systemctl --failed --no-legend --plain | awk '{print $1}' | tr '\n' ' ')"
  for u in unifi unifi-core rabbitmq-server ulp-go postgresql@14-main mongodb; do
    echo "$u=$(docker exec $NAME systemctl show $u -p ActiveState --value)/restarts=$(docker exec $NAME systemctl show $u -p NRestarts --value)"; done
  echo "network_rmq_conn=$(docker exec $NAME bash -c 'ss -tn state established "( dport = :5672 )" | tail -n +2 | wc -l')"
  echo "mongo27017_listening=$(docker exec $NAME bash -c 'ss -tln | grep -c ":27017 "')"
  echo "oom_kills=$(cat $CG/memory.events | awk '/oom_kill /{print $2}')"
} > "$H"
python3 - "$OUT" "$READY" "$CPU_READY" "$CPU_SETTLED" "$OPTS" <<'PY'
import csv,json,sys,statistics as st
out,ready,cr,cs,opts=sys.argv[1:]
rows=list(csv.DictReader(open(out+'/samples.csv')))
f=lambda k:[float(r[k]) for r in rows]
h=dict(l.strip().split('=',1) for l in open(out+'/health.txt') if '=' in l)
res={"options":json.loads(opts),"ready_s":ready,"cpu_s_to_ready":float(cr),"cpu_s_first_settle":float(cs),
 "mem_mib_avg":round(st.mean(f('mem_mib'))),"mem_mib_end":f('mem_mib')[-1],"anon_mib_avg":round(st.mean(f('anon_mib'))),
 "mem_growth_mib":f('mem_mib')[-1]-f('mem_mib')[0],
 "cpu_pct_avg":round(st.mean(f('cpu_pct')),2),"cpu_pct_median":st.median(f('cpu_pct')),
 "network_up": '"up":true' in h.get('network_status',''), "core_https":h.get('core_https'),
 "failed_units":h.get('failed_units','').strip(),"oom_kills":h.get('oom_kills'),
 "health":h}
svc={}
for l in open(out+'/services.txt'):
    p=l.split()
    if len(p)==3 and p[1].isdigit(): svc[p[0]]=round(int(p[1])/1048576)
res["services_mib"]=svc
json.dump(res,open(out+'/summary.json','w'),indent=1)
print(json.dumps({k:v for k,v in res.items() if k not in('health','services_mib')}))
PY
