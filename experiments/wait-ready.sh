#!/bin/bash
# Wait until UniFi Network (java) answers on 8080 inside the container and
# unifi-core answers on 443. Prints seconds to ready.
NAME=$1; T0=$(date +%s); LIMIT=${2:-900}
while :; do
  now=$(( $(date +%s) - T0 ))
  if docker exec "$NAME" bash -c 'curl -sk -o /dev/null -w "%{http_code}" https://127.0.0.1:443/ | grep -qE "^(200|302|301)$" && curl -s -o /dev/null http://127.0.0.1:8080/status' 2>/dev/null; then
    echo "$now"; exit 0; fi
  [ $now -gt $LIMIT ] && { echo "TIMEOUT"; exit 1; }
  sleep 5
done
