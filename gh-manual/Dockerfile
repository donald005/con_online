# syntax=docker/dockerfile:1
# ghost-manual 一体版：xray + cloudflared + 每月自动更新，全部封装在一个 Dockerfile 里
# 只需要这一个文件就能部署。
# 伪装页面：构建时从 https://esm.sh/gh/donald005/laofujs@main/index.html
# 下载，busybox-extras httpd 在 3001 上提供，浏览器访问域名时看到的就是这个页面。
# 页面内容在 laofujs 仓库里维护，改页面不用动 Dockerfile，下次容器启动即生效。
# 构建: docker build -t ghost-manual:latest .
# 运行: docker run -d --restart unless-stopped --name ghost-manual \
#         -e UUID='你的UUID' -e ARGO_AUTH='你的隧道token' \
#         -e WS_PATH='asd' -e ARGO_DOMAIN='www.google.com' \
#         ghost-manual:latest
# 部署时拉取最新版：容器每次启动都尝试拉取最新 xray / cloudflared / 伪装页，
# 拉不到就用镜像里构建时自带的版本继续跑（镜像仍会在构建时下一份当保底）。
# 每月 1 日 06:00（北京时间）再自动检查一次，有更新就热更新容器内的二进制
# （长期运行不重启的容器也保持最新）。更新只活在容器可写层，
# 删容器/重新部署后回到镜像里的旧版，下次启动时再拉最新。
# 更新对象只是 xray 和 cloudflared 两个二进制：只查 GitHub release，不从 Docker Hub 拉取/推送 ghost-manual 镜像。
# 不需要挂 docker socket：容器不操作宿主机 docker，更新全靠容器内下载替换。
# 立即手动跑一次自更新：建容器时加 -e UPDATE_NOW=1。
FROM alpine:3

ARG TARGETARCH

RUN apk add --no-cache ca-certificates curl unzip tzdata busybox-extras \
 && case "${TARGETARCH}" in \
      amd64) XRAY_ZIP="Xray-linux-64.zip";          CF_BIN="cloudflared-linux-amd64" ;; \
      arm64) XRAY_ZIP="Xray-linux-arm64-v8a.zip";   CF_BIN="cloudflared-linux-arm64" ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && curl -fL --retry 3 --max-time 180 \
      "https://github.com/XTLS/Xray-core/releases/latest/download/${XRAY_ZIP}" \
      -o /tmp/xray.zip \
 && unzip -q -o /tmp/xray.zip xray -d /usr/local/bin \
 && chmod +x /usr/local/bin/xray \
 && curl -fL --retry 3 --max-time 180 \
      "https://github.com/cloudflare/cloudflared/releases/latest/download/${CF_BIN}" \
      -o /usr/local/bin/cloudflared \
 && chmod +x /usr/local/bin/cloudflared \
 && mkdir -p /www \
 && curl -fL --retry 3 --max-time 60 \
      "https://esm.sh/gh/donald005/laofujs@main/index.html" \
      -o /www/index.html \
 && rm -f /tmp/xray.zip \
 && /usr/local/bin/xray version | head -1 \
 && /usr/local/bin/cloudflared --version | head -1

# 入口脚本（含每月自更新循环）由下面这段生成。
RUN <<'EOS'
cat > /usr/local/bin/entrypoint.sh <<'SCRIPT'
#!/bin/sh
# ghost-manual 一体版入口：生成 xray 配置 -> 启动 xray + cloudflared + 伪装页面 -> 多进程守护
# + 启动时拉取最新版：每次启动都尝试拉取最新 xray / cloudflared / 伪装页，
#   拉不到就用镜像自带版本。每月 1 日 06:00（北京时间）再检查一次，有更新就热更新。
#   更新的只是这两个二进制，不拉取/推送 ghost-manual 镜像，不操作宿主机 docker。
#   热更新是直接下载新版二进制替换 /usr/local/bin 里的旧版，再重启容器生效。
set -eu

UUID="${UUID:?环境变量 UUID 未设置}"
ARGO_AUTH="${ARGO_AUTH:?环境变量 ARGO_AUTH 未设置}"
ARGO_DOMAIN="${ARGO_DOMAIN:-www.google.com}"
XRAY_PORT="${XRAY_PORT:-8001}"
XRAY_LOGLEVEL="${XRAY_LOGLEVEL:-warning}"
XRAY_ACCESS_LOG="${XRAY_ACCESS_LOG:-}"
WS_PATH="${WS_PATH:-asd}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---------- 处理 WS_PATH ----------
# 去掉首尾空格和斜杠，再统一加上前导 /
WS_PATH=$(printf '%s' "$WS_PATH" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s|^/*||;s|/*$||')
if [ -n "$WS_PATH" ]; then
  WS_PATH="/$WS_PATH"
else
  WS_PATH=""
fi

VLESS_PATH="${WS_PATH}/vless-argo"
VMESS_PATH="${WS_PATH}/vmess-argo"
TROJAN_PATH="${WS_PATH}/trojan-argo"

log "使用路径: VLESS=${VLESS_PATH}  VMess=${VMESS_PATH}  Trojan=${TROJAN_PATH}"
[ -n "$ARGO_DOMAIN" ] || log "警告: ARGO_DOMAIN 为空，节点链接将无法生成（不影响隧道本身）"

# ---------- 启动时拉取最新版 ----------
# 容器每次启动都尝试拉取最新 xray / cloudflared / 伪装页；
# 拉不到就用镜像自带版本继续跑，不会因为 GitHub 一时连不上就起不来。
startup_fetch() {
  if curl -fL --retry 2 --max-time 60 "https://esm.sh/gh/donald005/laofujs@main/index.html" -o /tmp/index.html 2>/dev/null && [ -s /tmp/index.html ]; then
    mkdir -p /www
    if mv -f /tmp/index.html /www/index.html 2>/dev/null; then
      log "启动拉取：伪装页已更新为最新版"
    else
      rm -f /tmp/index.html
      log "启动拉取：伪装页替换失败，用镜像自带版本"
    fi
  else
    rm -f /tmp/index.html
    log "启动拉取：伪装页下载失败，用镜像自带版本"
  fi

  XRAY_TAG="$(curl -fsSL --max-time 30 'https://api.github.com/repos/XTLS/Xray-core/releases/latest' 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"//; s/"$//')"
  XRAY_LATEST="${XRAY_TAG#v}"
  CF_LATEST="$(curl -fsSL --max-time 30 'https://api.github.com/repos/cloudflare/cloudflared/releases/latest' 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"//; s/"$//')"
  if [ -z "$XRAY_LATEST" ] || [ -z "$CF_LATEST" ]; then
    log "启动拉取：获取最新版本失败，用镜像自带版本"
    return 0
  fi

  case "$(uname -m)" in
    x86_64)  XRAY_ZIP="Xray-linux-64.zip";        CF_BIN="cloudflared-linux-amd64" ;;
    aarch64) XRAY_ZIP="Xray-linux-arm64-v8a.zip"; CF_BIN="cloudflared-linux-arm64" ;;
    *) log "启动拉取：不支持的架构 $(uname -m)，用镜像自带版本"; return 0 ;;
  esac

  XRAY_CUR="$(/usr/local/bin/xray version 2>/dev/null | head -1 | awk '{print $2}')"
  if [ "$XRAY_CUR" != "$XRAY_LATEST" ]; then
    log "启动拉取：下载 xray $XRAY_LATEST（当前 ${XRAY_CUR:-无}）"
    rm -f /tmp/xray.zip
    if curl -fL --retry 3 --max-time 180 "https://github.com/XTLS/Xray-core/releases/download/${XRAY_TAG}/${XRAY_ZIP}" -o /tmp/xray.zip 2>/dev/null; then
      rm -rf /tmp/xray-new && mkdir -p /tmp/xray-new
      if unzip -q -o /tmp/xray.zip xray -d /tmp/xray-new 2>/dev/null; then
        chmod +x /tmp/xray-new/xray
        NEW_VER="$(/tmp/xray-new/xray version 2>/dev/null | head -1 | awk '{print $2}')"
        XRAY_OK=0
        if [ "$NEW_VER" = "$XRAY_LATEST" ]; then
          if /tmp/xray-new/xray test -c /etc/xray/config.json >/dev/null 2>&1 || /tmp/xray-new/xray -test -config /etc/xray/config.json >/dev/null 2>&1; then
            log "启动拉取：新 xray 配置校验通过"
            XRAY_OK=1
          elif /tmp/xray-new/xray help 2>&1 | grep -qw "test"; then
            log "启动拉取：新 xray 配置校验失败，用镜像自带版本"
          else
            log "启动拉取：新 xray 无 test 子命令，跳过配置校验"
            XRAY_OK=1
          fi
        else
          log "启动拉取：新 xray 版本校验失败（得到 ${NEW_VER:-?}），用镜像自带版本"
        fi
        if [ "$XRAY_OK" = "1" ]; then
          cp -f /usr/local/bin/xray /usr/local/bin/xray.bak 2>/dev/null || true
          if mv -f /tmp/xray-new/xray /usr/local/bin/xray 2>/dev/null; then
            log "启动拉取：xray 已更新为 $XRAY_LATEST"
          else
            log "启动拉取：xray 替换失败，用镜像自带版本"
          fi
        fi
      else
        log "启动拉取：xray 解压失败，用镜像自带版本"
      fi
      rm -f /tmp/xray.zip; rm -rf /tmp/xray-new
    else
      rm -f /tmp/xray.zip
      log "启动拉取：xray 下载失败，用镜像自带版本"
    fi
  else
    log "启动拉取：xray 已是最新 $XRAY_CUR"
  fi

  CF_CUR="$(/usr/local/bin/cloudflared --version 2>/dev/null | awk '{print $3}')"
  if [ "$CF_CUR" != "$CF_LATEST" ]; then
    log "启动拉取：下载 cloudflared $CF_LATEST（当前 ${CF_CUR:-无}）"
    rm -f /tmp/cloudflared-new
    if curl -fL --retry 3 --max-time 180 "https://github.com/cloudflare/cloudflared/releases/download/${CF_LATEST}/${CF_BIN}" -o /tmp/cloudflared-new 2>/dev/null; then
      chmod +x /tmp/cloudflared-new
      NEW_VER="$(/tmp/cloudflared-new --version 2>/dev/null | awk '{print $3}')"
      if [ "$NEW_VER" = "$CF_LATEST" ]; then
        cp -f /usr/local/bin/cloudflared /usr/local/bin/cloudflared.bak 2>/dev/null || true
        if mv -f /tmp/cloudflared-new /usr/local/bin/cloudflared 2>/dev/null; then
          log "启动拉取：cloudflared 已更新为 $CF_LATEST"
        else
          log "启动拉取：cloudflared 替换失败，用镜像自带版本"
        fi
      else
        log "启动拉取：新 cloudflared 版本校验失败（得到 ${NEW_VER:-?}），用镜像自带版本"
        rm -f /tmp/cloudflared-new
      fi
    else
      rm -f /tmp/cloudflared-new
      log "启动拉取：cloudflared 下载失败，用镜像自带版本"
    fi
  else
    log "启动拉取：cloudflared 已是最新 $CF_CUR"
  fi
  return 0
}

# ---------- 生成 xray 配置 ----------
mkdir -p /etc/xray
cat > /etc/xray/config.json <<EOF
{
  "log": { "loglevel": "${XRAY_LOGLEVEL}", "access": "${XRAY_ACCESS_LOG}", "error": "/dev/stderr" },
  "inbounds": [
    {
      "tag": "vless-fallback-in", "port": ${XRAY_PORT}, "listen": "::",
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "${UUID}", "flow": "xtls-rprx-vision" } ],
        "decryption": "none",
        "fallbacks": [
          { "dest": 3001 },
          { "path": "${VLESS_PATH}", "dest": 3002 },
          { "path": "${VMESS_PATH}", "dest": 3003 },
          { "path": "${TROJAN_PATH}", "dest": 3004 }
        ]
      },
      "streamSettings": { "network": "tcp" }
    },
    {
      "tag": "vless-ws-in", "port": 3002, "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [ { "id": "${UUID}", "level": 0 } ], "decryption": "none" },
      "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "${VLESS_PATH}" } }
    },
    {
      "tag": "vmess-ws-in", "port": 3003, "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "${UUID}", "alterId": 0 } ] },
      "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "${VMESS_PATH}" } }
    },
    {
      "tag": "trojan-ws-in", "port": 3004, "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": { "clients": [ { "password": "${UUID}" } ] },
      "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "${TROJAN_PATH}" } }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

startup_fetch

# ---------- 配置校验 ----------
if /usr/local/bin/xray test -c /etc/xray/config.json >/dev/null 2>&1; then
  log "xray 配置校验通过"
elif /usr/local/bin/xray -test -config /etc/xray/config.json >/dev/null 2>&1; then
  log "xray 配置校验通过"
else
  case "${UUID}" in
    ????????-????-????-????-????????????) log "xray 无内置校验命令，UUID 格式正常，跳过校验" ;;
    *) log "UUID 格式不正确: ${UUID}"; exit 1 ;;
  esac
fi

# ---------- 生成节点链接 ----------
if [ -n "$ARGO_DOMAIN" ]; then
  VLESS_URL="vless://${UUID}@${ARGO_DOMAIN}:443?encryption=none&security=tls&sni=${ARGO_DOMAIN}&fp=chrome&type=ws&path=${VLESS_PATH}#VLESS-WS"
  TROJAN_URL="trojan://${UUID}@${ARGO_DOMAIN}:443?security=tls&sni=${ARGO_DOMAIN}&fp=chrome&type=ws&path=${TROJAN_PATH}#Trojan-WS"
  VMESS_JSON="{\"v\":\"2\",\"ps\":\"VMess-WS\",\"add\":\"${ARGO_DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${ARGO_DOMAIN}\",\"path\":\"${VMESS_PATH}\",\"tls\":\"tls\",\"sni\":\"${ARGO_DOMAIN}\",\"fp\":\"chrome\"}"
  VMESS_B64="$(printf '%s' "$VMESS_JSON" | base64 | tr -d '\n')"
  VMESS_URL="vmess://${VMESS_B64}"
  log "================ 节点链接 ================"
  printf '%s\n' "$VLESS_URL" "$VMESS_URL" "$TROJAN_URL"
  log "=========================================="
fi

# ---------- 每月自更新 ----------
# 容器内热更新：直接下载新版二进制替换 /usr/local/bin 里的旧版，再重启容器生效。
# 更新只活在容器可写层里：重启还在，容器被删/重新部署后回到镜像里的旧版。
inplace_update() {
  XRAY_TAG="$(curl -fsSL --max-time 30 'https://api.github.com/repos/XTLS/Xray-core/releases/latest' 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"//; s/"$//')"
  XRAY_LATEST="${XRAY_TAG#v}"
  CF_LATEST="$(curl -fsSL --max-time 30 'https://api.github.com/repos/cloudflare/cloudflared/releases/latest' 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"//; s/"$//')"
  if [ -z "$XRAY_LATEST" ] || [ -z "$CF_LATEST" ]; then
    log "热更新：获取最新版本失败，跳过"
    return 1
  fi

  XRAY_CUR="$(/usr/local/bin/xray version 2>/dev/null | head -1 | awk '{print $2}')"
  CF_CUR="$(/usr/local/bin/cloudflared --version 2>/dev/null | awk '{print $3}')"
  if [ -z "$XRAY_CUR" ] || [ -z "$CF_CUR" ]; then
    log "热更新：读取当前版本失败，跳过"
    return 1
  fi

  log "热更新检查：xray 当前 $XRAY_CUR / 最新 $XRAY_LATEST；cloudflared 当前 $CF_CUR / 最新 $CF_LATEST"
  if [ "$XRAY_CUR" = "$XRAY_LATEST" ] && [ "$CF_CUR" = "$CF_LATEST" ]; then
    log "热更新：两个都已是最新，不更新"
    return 0
  fi

  case "$(uname -m)" in
    x86_64)  XRAY_ZIP="Xray-linux-64.zip";        CF_BIN="cloudflared-linux-amd64" ;;
    aarch64) XRAY_ZIP="Xray-linux-arm64-v8a.zip"; CF_BIN="cloudflared-linux-arm64" ;;
    *) log "热更新：不支持的架构 $(uname -m)"; return 1 ;;
  esac

  CHANGED=0
  if [ "$XRAY_CUR" != "$XRAY_LATEST" ]; then
    log "热更新：下载 xray $XRAY_LATEST"
    rm -f /tmp/xray.zip
    if ! curl -fL --retry 3 --max-time 180 "https://github.com/XTLS/Xray-core/releases/download/${XRAY_TAG}/${XRAY_ZIP}" -o /tmp/xray.zip 2>/dev/null; then
      log "热更新：xray 下载失败，本轮不更新"
      rm -f /tmp/xray.zip
      return 1
    fi
    rm -rf /tmp/xray-new && mkdir -p /tmp/xray-new
    if ! unzip -q -o /tmp/xray.zip xray -d /tmp/xray-new 2>/dev/null; then
      log "热更新：xray 解压失败，本轮不更新"
      rm -f /tmp/xray.zip; rm -rf /tmp/xray-new
      return 1
    fi
    chmod +x /tmp/xray-new/xray
    NEW_VER="$(/tmp/xray-new/xray version 2>/dev/null | head -1 | awk '{print $2}')"
    if [ "$NEW_VER" != "$XRAY_LATEST" ]; then
      log "热更新：新 xray 版本校验失败（得到 ${NEW_VER:-?}，期望 $XRAY_LATEST），本轮不更新"
      rm -f /tmp/xray.zip; rm -rf /tmp/xray-new
      return 1
    fi
    if /tmp/xray-new/xray test -c /etc/xray/config.json >/dev/null 2>&1 || /tmp/xray-new/xray -test -config /etc/xray/config.json >/dev/null 2>&1; then
      log "热更新：新 xray 配置校验通过"
    elif /tmp/xray-new/xray help 2>&1 | grep -qw "test"; then
      log "热更新：新 xray 配置校验失败，本轮不更新"
      rm -f /tmp/xray.zip; rm -rf /tmp/xray-new
      return 1
    else
      log "热更新：新 xray 无 test 子命令，跳过配置校验"
    fi
    cp -f /usr/local/bin/xray /usr/local/bin/xray.bak 2>/dev/null || true
    mv -f /tmp/xray-new/xray /usr/local/bin/xray
    rm -f /tmp/xray.zip; rm -rf /tmp/xray-new
    log "热更新：xray 已替换为 $XRAY_LATEST"
    CHANGED=1
  fi
  if [ "$CF_CUR" != "$CF_LATEST" ]; then
    log "热更新：下载 cloudflared $CF_LATEST"
    rm -f /tmp/cloudflared-new
    if ! curl -fL --retry 3 --max-time 180 "https://github.com/cloudflare/cloudflared/releases/download/${CF_LATEST}/${CF_BIN}" -o /tmp/cloudflared-new 2>/dev/null; then
      log "热更新：cloudflared 下载失败，本轮不更新"
      rm -f /tmp/cloudflared-new
      return 1
    fi
    chmod +x /tmp/cloudflared-new
    NEW_VER="$(/tmp/cloudflared-new --version 2>/dev/null | awk '{print $3}')"
    if [ "$NEW_VER" != "$CF_LATEST" ]; then
      log "热更新：新 cloudflared 版本校验失败（得到 ${NEW_VER:-?}，期望 $CF_LATEST），本轮不更新"
      rm -f /tmp/cloudflared-new
      return 1
    fi
    cp -f /usr/local/bin/cloudflared /usr/local/bin/cloudflared.bak 2>/dev/null || true
    mv -f /tmp/cloudflared-new /usr/local/bin/cloudflared
    log "热更新：cloudflared 已替换为 $CF_LATEST"
    CHANGED=1
  fi

  if [ "$CHANGED" = "0" ]; then
    return 0
  fi
  log "热更新完成，重启容器以生效"
  kill "$XPID" "$CPID" 2>/dev/null || true
  return 0
}

update_loop() {
  if [ "${UPDATE_NOW:-0}" = "1" ]; then
    inplace_update || log "自更新失败，1 小时后重试"
  fi
  while true; do
    DAY="$(TZ=Asia/Shanghai date +%d)"
    HOUR="$(TZ=Asia/Shanghai date +%H)"
    HOUR="${HOUR#0}"
    if [ "$DAY" = "01" ] && [ "$HOUR" -ge 6 ]; then
      inplace_update || log "自更新失败，1 小时后重试"
    fi
    sleep 3600
  done
}

# ---------- 启动 xray + cloudflared + 更新循环 ----------
/usr/local/bin/xray run -c /etc/xray/config.json &
XPID=$!
log "xray 已启动 (pid=${XPID})"

/usr/local/bin/cloudflared tunnel --no-autoupdate --protocol http2 run --token "${ARGO_AUTH}" &
CPID=$!
log "cloudflared 已启动 (pid=${CPID})"

# 伪装页面：busybox-extras httpd 在 3001 上提供 /www/index.html，
# xray 的默认 fallback（dest 3001）会把浏览器访问引到这里
[ -f /www/index.html ] || log "警告: /www/index.html 不存在，伪装页面将返回 404"
busybox-extras httpd -f -p 127.0.0.1:3001 -h /www &
HPID=$!
log "伪装页面已启动 (pid=${HPID})，http://127.0.0.1:3001/"

update_loop &
LPID=$!
log "自更新循环已启动 (pid=${LPID})，每月 1 日 06:00（北京时间）检查更新"

trap 'log "收到停止信号，退出"; kill "${XPID}" "${CPID}" "${LPID}" "${HPID}" 2>/dev/null || true; exit 0' TERM INT

while kill -0 "${XPID}" 2>/dev/null && kill -0 "${CPID}" 2>/dev/null && kill -0 "${HPID}" 2>/dev/null; do
  sleep 10
done
log "检测到子进程退出，容器退出以触发重启"
kill "${XPID}" "${CPID}" "${LPID}" "${HPID}" 2>/dev/null || true
exit 1
SCRIPT
chmod +x /usr/local/bin/entrypoint.sh
EOS

ENV UUID="" \
    ARGO_AUTH="" \
    ARGO_DOMAIN="www.google.com" \
    XRAY_PORT=8001 \
    WS_PATH="asd" \
    TZ=Asia/Shanghai

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
