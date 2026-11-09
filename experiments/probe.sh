s(){ echo; echo "######## $*"; }
s env files; cat /etc/default/unifi; echo ---; cat /var/lib/unifi/env-overrides; echo ---; ls -la /etc/default/ | head -50; cat /etc/default/unifi-core* 2>&1
s helper; file /usr/sbin/unifi-network-service-helper; head -c 20000 /usr/sbin/unifi-network-service-helper | strings | grep -n -i -E "jvm|xmx|ram|percent|env-overrides|mongodb|mongo" | head -80
s helper-fulltext-if-script; head -1 /usr/sbin/unifi-network-service-helper | grep -q '^#!' && cat /usr/sbin/unifi-network-service-helper
s grep env-overrides; grep -rl "env-overrides" /usr/sbin /usr/bin /usr/lib/unifi/bin /usr/share/unifi-core/app/hooks /usr/share/unifi 2>/dev/null | head
s grep MaxRAMPercentage; grep -rl "MaxRAMPercentage" /usr/sbin /usr/bin /usr/lib/unifi /usr/share/unifi /usr/share/unifi-core 2>/dev/null | head
s listening; ss -tlnp; s established; ss -tnp state established | sort | head -80
s mongo27017; mongo --quiet --port 27017 --eval 'printjson(db.adminCommand({listDatabases:1})); printjson(db.serverStatus().connections); printjson(db.adminCommand({currentOp:1, $all:true}).inprog.map(function(o){return [o.client, o.appName, o.desc]}))'
s mongo27117; mongo --quiet --port 27117 --eval 'printjson(db.adminCommand({listDatabases:1})); printjson(db.serverStatus().connections); var c=db.serverStatus().wiredTiger.cache; print(c["maximum bytes configured"], c["bytes currently in the cache"])'
s unifi-mongodb unit; systemctl status unifi-mongodb --no-pager | head -5; grep -rn "unifi-mongodb\|mongodb.service" /lib/systemd/system /etc/systemd/system 2>/dev/null | head
s ls unifi bin; ls -la /usr/lib/unifi/bin; readlink -f /usr/lib/unifi/bin/mongod
s journald; ls -la /var/log/journal /run/log/journal 2>&1; journalctl --header 2>/dev/null | grep -E "File path|File size" | head; grep -v '^#' /etc/systemd/journald.conf | grep .; ls /etc/systemd/journald.conf.d 2>&1
s rabbit conf; for f in /etc/rabbitmq/conf.d/*; do echo "== $f"; cat $f; done; cat /etc/rabbitmq/enabled_plugins; ps -o args= -C beam.smp | tr ' ' '\n' | head -80 | tr '\n' ' '
s gc log; tail -30 /usr/lib/unifi/logs/gc.log
s java; java -version 2>&1; which jcmd jstat jmap; ls /usr/lib/jvm
s java flags; java -XX:+PrintFlagsFinal -XX:+UseG1GC -XX:MaxRAMPercentage=70.0 -version 2>/dev/null | grep -E " MaxHeapSize| InitialHeapSize| ParallelGCThreads| ConcGCThreads| CICompilerCount |ReservedCodeCacheSize| MaxMetaspaceSize"
s java NMT-ish; cat /proc/$(pgrep -f ace.jar)/status | grep -E "VmRSS|RssAnon|RssFile|Threads"
s node; cat /proc/$(pgrep -x unifi-core)/status | grep -E "VmRSS|RssAnon|Threads"
s pg settings; su postgres -c "psql -At -c 'show shared_buffers' -c 'show max_connections' -c 'show work_mem' -c 'select usename, count(*) from pg_stat_activity group by 1'"; ls /etc/postgresql/14/main/conf.d; cat /etc/postgresql/14/main/conf.d/* 2>/dev/null
s service wants; systemctl list-dependencies multi-user.target --no-pager | head -60
s mongod.service deps; systemctl list-dependencies --reverse mongodb.service --no-pager
s timers detail; systemctl list-timers --all --no-pager; systemctl cat apt-daily.service | grep ExecStart
s cron; ls /etc/cron.*; cat /etc/crontab | grep -v '^#'
s failed; systemctl --failed --no-pager
s identity units; for u in ulp-go unifi-directory uid-agent ucs-agent unifi-identity-update uos-agent uos-discovery-client snmpd; do echo "== $u"; systemctl show $u -p Description,WantedBy,RequiredBy,Wants,Requires --no-pager; done
s unifi-core reverse deps; systemctl show unifi-core -p Wants,Requires,After --no-pager
s tmpfs usage; df -h /tmp /run /var/lib/journal /var/opt/unifi/tmp
s proc vm; cat /proc/sys/vm/swappiness; touch /proc/sys/vm/swappiness 2>&1; sysctl -w vm.swappiness=10 2>&1
