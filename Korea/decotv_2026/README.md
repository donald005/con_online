# DecoTV + Cloudflare Tunnel 自动更新方案

目标：`cloudflared`、`decotv-core`、`watchtower` 三个镜像都保持 `latest`，
每天北京时间 06:00 检查一次，有新 digest 就拉取并重建容器。

## 结构

- `docker-compose.yml`：三个服务 + `mynetwork`（10.30.0.0/24）
- `.env.example`：复制成 `.env` 后填真实 token / 账号密码
- `update.sh`：手动立即更新，或给 cron 用的兜底脚本

## 关键设计

1. **watchtower 换镜像**：`containrrr/watchtower` 已于 2025-12-17 归档，
   停在 v1.7.1 不再有安全更新，改用维护中的 fork `nickfedor/watchtower`，
   环境变量和命令行用法完全相同。
2. **三个都监控**：watchtower 命令里写 `cftunnel decotv-core watchtower`，
   watchtower 自己在列表里时也会自我更新。只写 `decotv-core` 的话，
   隧道永远停在第一次拉取的版本。
3. **固定时间更新**：`WATCHTOWER_SCHEDULE=0 0 6 * * *` + `TZ=Asia/Shanghai`，
   每天 06:00 检查。不要同时再设 `WATCHTOWER_POLL_INTERVAL`，两者只能二选一。
4. **逐个重启**：`--rolling-restart`，先更新一个、拉起来再更新下一个，
   避免隧道和应用同时停。
5. **cloudflared 保留 `--no-autoupdate`**：版本以镜像为准，
   容器内二进制自升级会在重建后丢失，还可能在不恰当的时间重启隧道。
6. **旧镜像清理**：`WATCHTOWER_CLEANUP=true`，更新成功后删旧镜像。
   代价是回滚要重新拉旧 digest，见下文。

## 部署步骤（在部署机器上跑）

```bash
mkdir -p /root/decotv && cd /root/decotv
# 把 docker-compose.yml、update.sh 传到这里，.env 按 .env.example 新建
cp .env.example .env
nano .env          # 填 CF_TOKEN、USERNAME、PASSWORD、UPSTASH_URL、UPSTASH_TOKEN
chmod 600 .env
chmod +x update.sh

# 如果之前是用 docker run 起的老容器，先清掉，避免名字和网络冲突
docker rm -f cftunnel decotv-core watchtower 2>/dev/null || true
docker network rm mynetwork 2>/dev/null || true

docker compose up -d
docker compose ps
docker compose logs -f watchtower   # 看到 schedule / watching 字样就正常
docker compose logs cftunnel        # 看到 Registered tunnel connection 即隧道通了
```

Cloudflare 后台另需配好（只做一次，更新不影响它）：
Zero Trust -> Networks -> Tunnels -> 该 tunnel -> Public Hostname，
Service 填 `http://decotv-core:3000`。

## 验证更新真的在跑

```bash
# 1. 看 watchtower 日志（每天 06:00 前后）
docker compose logs --since 24h watchtower | grep -iE 'found new|stopping|starting|session'

# 2. 看三个镜像的 ID / 创建时间是不是变了
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.CreatedAt}}' \
  | grep -E 'cloudflared|decotv|watchtower'

# 3. 看 cloudflared 版本
docker exec cftunnel cloudflared --version

# 4. 手动触发一次更新测试（不改定时任务）
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  nickfedor/watchtower:latest --run-once --cleanup cftunnel decotv-core watchtower
```

## 手动更新 / cron 兜底

watchtower 是主路径。`update.sh` 是手动或 cron 的备用，
两者不要同时开定时（会重复拉取、重复重启）。

```bash
./update.sh
# 或加到 crontab，每天 06:30 跑一次（和 watchtower 错开半小时）
# 30 6 * * * cd /root/decotv && ./update.sh >> /var/log/decotv-update.log 2>&1
```

## 回滚

`--cleanup` 会删旧镜像，所以回滚要靠重新拉：

```bash
# 1. 先看 GHCR / Docker Hub 上上一个可用的 tag 或 digest
# 2. 临时把 docker-compose.yml 里出问题的那个 image 改成带 digest 的版本，例如：
#    image: ghcr.io/decohererk/decotv@sha256:<上一个 digest>
#    image: cloudflare/cloudflared@sha256:<上一个 digest>
# 3. 重建
docker compose up -d <服务名>
# 4. 确认恢复后，再把 image 改回 :latest，等下一个稳定版
```

如果经常要回滚，把 `WATCHTOWER_CLEANUP` 改成 `false`，
改成每周手动 `docker image prune -a --filter "until=168h" -f` 清理，
这样旧镜像会留在本地，回滚就是改 tag 重建。

## 常见问题

- 06:00 没更新：先看 `docker compose logs watchtower`，确认 TZ 和 schedule
  生效；再看是不是 registry 当时没发新版，`latest` 没变就不动是正常的。
- 隧道更新后短暂断开：正常，cloudflared 重建后 10 秒内会重新注册，
  看 `docker compose logs cftunnel` 确认 `Registered tunnel connection`。
- decotv 更新后登录 / 收藏丢了：说明 Upstash 没接通，数据落在本地，
  容器重建就丢。先查 `docker compose logs decotv-core` 的 Upstash 报错，
  再按上一条的 NEXT_PUBLIC 构建时变量问题排查。
- watchtower 自己没更新：确认命令里写了 `watchtower` 这个名字，
  且没有用 `--label-enable` 模式把自己排除在外。
