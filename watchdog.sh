#!/bin/bash

# the services to be monitored
SERVICES=("mock-api.service" "yolo-app.service" "redis-server.service")

for SERVICE in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$SERVICE"; then
        echo "$(date): $SERVICE is not active. Restarting..." >> /var/log/watchdog.log
        systemctl restart "$SERVICE"
    fi
done
