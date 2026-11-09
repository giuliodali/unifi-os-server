#!/bin/bash
# Dump everything useful about what runs inside the container.
NAME=$1 OUT=$2; mkdir -p "$OUT"
x(){ docker exec "$NAME" bash -c "$1" > "$OUT/$2" 2>&1; }
x 'systemctl list-units --type=service --all --no-pager' services.txt
x 'systemctl list-unit-files --no-pager' unit-files.txt
x 'systemctl list-timers --all --no-pager' timers.txt
x 'ps -eo pid,ppid,rss,vsz,pcpu,cputime,etime,user,args --sort=-rss | cut -c1-600' ps.txt
x 'systemd-cgtop -b -n 2 -d 10 --depth=3 -m --raw' cgtop-mem.txt
x 'systemd-cgtop -b -n 2 -d 10 --depth=3 -c --raw' cgtop-cpu.txt
x 'for u in $(systemctl list-units --type=service --state=running --no-legend --plain | awk "{print \$1}"); do echo "######## $u"; systemctl cat $u; systemctl show $u -p MemoryCurrent,CPUUsageNSec,Restart,ExecStart; done' unit-defs.txt
x 'for p in $(pgrep -f java); do echo "## $p"; tr "\0" " " < /proc/$p/cmdline; echo; done; for p in $(pgrep -f node); do echo "## $p"; tr "\0" " " < /proc/$p/cmdline; echo; done' cmdlines.txt
x 'cat /etc/mongod.conf /etc/mongodb.conf 2>/dev/null; ls -la /etc/mongo* ; mongod --version | head -3; ls /usr/bin | grep -i mongo' mongo.txt
x 'mongosh --quiet --port 27117 --eval "db.serverStatus().wiredTiger.cache[\"maximum bytes configured\"]; db.adminCommand({getCmdLineOpts:1})" 2>&1; mongo --quiet --port 27117 --eval "printjson(db.adminCommand({getCmdLineOpts:1}))" 2>&1' mongo-live.txt
x 'ls /etc/postgresql/*/main; grep -vE "^\s*(#|$)" /etc/postgresql/*/main/postgresql.conf; ls /etc/postgresql/*/main/conf.d; cat /etc/postgresql/*/main/conf.d/* 2>/dev/null; su postgres -c "psql -At -c \"select name,setting,unit from pg_settings where name in (\x27shared_buffers\x27,\x27max_connections\x27,\x27work_mem\x27,\x27maintenance_work_mem\x27,\x27effective_cache_size\x27,\x27max_worker_processes\x27,\x27autovacuum_max_workers\x27);\" ; psql -At -c \"select datname, pg_database_size(datname) from pg_database\"; psql -At -c \"select count(*) from pg_stat_activity\""' postgres.txt
x 'ls -la /etc/rabbitmq; cat /etc/rabbitmq/*.conf /etc/rabbitmq/rabbitmq-env.conf /etc/rabbitmq/advanced.config 2>/dev/null; rabbitmqctl status 2>&1 | head -80; rabbitmq-diagnostics memory_breakdown 2>&1 | head -40' rabbitmq.txt
x 'cat /var/lib/unifi/system.properties; ls -la /usr/lib/unifi /usr/lib/unifi/data 2>&1; cat /usr/lib/unifi/data/system.properties 2>/dev/null; cat /etc/default/unifi 2>/dev/null; grep -rn "xmx\|Xmx\|JVM" /usr/lib/unifi/bin /usr/sbin/unifi* /etc/default/unifi* /lib/systemd/system/unifi*.service 2>/dev/null | head -40' unifi-network.txt
x 'dpkg -l | awk "/^ii/{print \$2, \$3}"' packages.txt
x 'cat /proc/meminfo; free -m; nproc; cat /sys/fs/cgroup/memory.max; cat /sys/fs/cgroup/cpu.max; cat /proc/pressure/cpu /proc/pressure/memory 2>/dev/null' system.txt
x 'journalctl --disk-usage; du -sh /var/log/* /var/lib/* 2>/dev/null | sort -h | tail -20; df -h' disk.txt
x 'journalctl -b --no-pager -p warning | tail -300' journal-warn.txt
x 'top -b -n 4 -d 15 -o %CPU | head -200' top.txt
x 'ls /usr/share/unifi-core 2>/dev/null; ls /usr/lib/unifi-core 2>/dev/null; ls /usr/share/ | grep -i -E "unifi|uos|ulp|ucore"; ls /etc/ | grep -i -E "unifi|uos|ulp"; find / -xdev -name "*.yaml" -path "*unifi*" 2>/dev/null | head -30; find / -xdev -name "config*.json" -path "*unifi-core*" 2>/dev/null | head' layout.txt
x 'cat /proc/sys/vm/swappiness /proc/sys/vm/overcommit_memory; for p in $(pgrep -f "java|node|mongod|beam|postgres"); do echo "$p $(cat /proc/$p/comm) threads=$(ls /proc/$p/task|wc -l)"; done' threads.txt
