#!/bin/bash
# 手动更新脚本：watchtower 的兜底 / 手动立即更新用
# 用法：./update.sh
# 定时跑它就等于不用 watchtower 的 cron，二选一，不要两边同时开
set -euo pipefail
cd "$(dirname "$0")"

echo "[$(date '+%F %T')] pull latest images..."
docker compose pull cftunnel decotv-core watchtower

echo "[$(date '+%F %T')] recreate changed containers..."
docker compose up -d

echo "[$(date '+%F %T')] wait 20s for healthcheck..."
sleep 20
docker compose ps

echo "[$(date '+%F %T')] healthcheck decotv-core..."
docker exec decotv-core node -e "fetch('http://127.0.0.1:3000').then(r=>{console.log('decotv http', r.status); process.exit(r.ok?0:1)}).catch(e=>{console.error(e.message); process.exit(1)})"

echo "[$(date '+%F %T')] versions..."
docker exec cftunnel cloudflared --version || true
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.CreatedAt}}' | grep -E 'cloudflared|decotv|watchtower' || true

echo "[$(date '+%F %T')] prune dangling images..."
docker image prune -f

echo "[$(date '+%F %T')] done."
