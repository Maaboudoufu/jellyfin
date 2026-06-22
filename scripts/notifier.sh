#!/bin/sh
# Watch docker events and push a ntfy.sh notification when any container becomes unhealthy.
set -e
apk add --no-cache docker-cli curl tzdata >/dev/null 2>&1 || true

if [ -z "$NTFY_TOPIC" ]; then
  echo "NTFY_TOPIC not set in .env; notifier idle"
  sleep infinity
fi

HOST=$(hostname)
echo "watching docker health events; alerting to ntfy.sh/$NTFY_TOPIC"

docker events --filter event=health_status --filter health_status=unhealthy --format '{{.Actor.Attributes.name}}' \
  | while read -r name; do
      ts=$(date -Iseconds)
      echo "$ts $name became unhealthy"
      curl -sS \
        -H "Title: container unhealthy on $HOST" \
        -H "Priority: high" \
        -H "Tags: warning,docker" \
        -d "$name became unhealthy at $ts" \
        "https://ntfy.sh/$NTFY_TOPIC" >/dev/null || true
    done
