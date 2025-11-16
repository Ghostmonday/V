#!/bin/bash
# Repair script for high latency
# Restart Redis cache

docker compose -f docker-compose.yml restart redis || echo "Restart failed"
echo "Restarted Redis for latency issues"

