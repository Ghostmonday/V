#!/bin/bash
# Repair script for high CPU usage
# Scale up backend instances

docker compose -f docker-compose.yml scale api=2 || echo "Scaling failed"
echo "Scaled backend for high CPU"

