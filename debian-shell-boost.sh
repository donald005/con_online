#!/usr/bin/env bash
#
# debian-shell-boost.sh — Debian / Ubuntu 全系统配置三项功能
#
#   1) ll / la / l 别名（GNU ls 自动带颜色）
#   2) 命令找不到时，提示对应软件包与安装命令
#   3) Tab 补全（bash-completion + readline 优化：一次 Tab 列出全部候选）
#
# 作用范围：系统中所有 bash 用户（含后续新建用户）
#
# 用法：
#   sudo bash debian-shell-boost.sh              # 安装 / 更新（全部用户）
#   bash debian-shell-boost.sh --dry-run         # 只打印将写入的内容
#   sudo bash debian-shell-boost.sh --system-only # 只配 /etc 级，不碰用户家目录
#   sudo bash debian-shell-boost.sh --uninstall   # 从所有位置移除
#   bash debian-shell-boost.sh --help
#
# 分层设计（为什么不是只写 /etc/bash.bashrc）：
#   /etc/shell-boost.sh          唯一配置源，三项功能都在这里
#   /etc/bash.bashrc             系统级入口，覆盖所有交互式 bash
#   /etc/profile.d/99-*.sh       登录 shell 入口
#   ~/.bashrc（每个用户）        末尾注入钩子 —— 用户自己的 bashrc 在系统级之后
#                                加载，只有注入到最后，别名才不会被用户配置覆盖
#   /etc/skel/.bashrc            新建用户自动带钩子
#
# 幂等：靠 >>> shell-boost >>> 标记剥离旧段，重复执行不堆叠。
# 可回滚：每个被修改的文件都备份为 原文件名.bak.YYYYmmdd-HHMMSS。

set -uo pipefail

PAYLOAD="${SB_PAYLOAD:-/etc/shell-boost.sh}"
SYSTEM_RC="${SB_SYSTEM_RC:-/etc/bash.bashrc}"
PROFILE_D="${SB_PROFILE_D:-/etc/profile.d/99-shell-boost.sh}"
SKEL="${SB_SKEL:-/etc/skel/.bashrc}"

MARK_BEGIN='# >>> shell-boost >>>'
MARK_END='# <<< shell-boost <<<'

DRY_RUN=0
DO_DEPS=1
UNINSTALL=0
SYSTEM_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)     DRY_RUN=1 ;;
        --no-deps)     DO_DEPS=0 ;;
        --uninstall)   UNINSTALL=1 ;;
        --system-only) SYSTEM_ONLY=1 ;;
        -h|--help)     sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf '未知参数：%s（用 --help 查看用法）\n' "$arg" >&2; exit 2 ;;
    esac
done

c_ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$*"; }
c_info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
c_warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
c_err()  { printf '\033[31m[FAIL]\033[0m %s\n' "$*"; }

need_root() {
    if [ "$(id -u)" -ne 0 ]; then
        c_err "需要 root 权限：sudo bash $0"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# 唯一配置源：三项功能的实际实现
# ---------------------------------------------------------------------------
print_payload() {
cat <<'PAYLOAD'
#!/bin/bash
# /etc/shell-boost.sh — 由 debian-shell-boost.sh 生成，请勿手工编辑
# 三项功能：ll 别名 / 命令未找到提示 / Tab 补全
# 仅对交互式 bash 生效

case $- in
    *i*) ;;
    *)   return 0 2>/dev/null || exit 0 ;;
esac

# ---- 1) ls 别名 -----------------------------------------------------------
case "$(ls --version 2>/dev/null)" in
    *GNU*) alias ls='ls --color=auto' ;;
esac
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# ---- 2) Tab 补全 ----------------------------------------------------------
# 用 BASH_COMPLETION_VERSINFO 判断，避免被多处 source 时重复加载
if [ -z "${BASH_COMPLETION_VERSINFO-}" ]; then
    for _sb_c in /usr/share/bash-completion/bash_completion /etc/bash_completion; do
        if [ -r "$_sb_c" ]; then . "$_sb_c"; break; fi
    done
    unset _sb_c
fi
bind 'set show-all-if-ambiguous on' 2>/dev/null
bind 'set completion-ignore-case on' 2>/dev/null
bind 'set colored-stats on' 2>/dev/null
bind 'set visible-stats on' 2>/dev/null

# ---- 3) 命令找不到时提示安装 ---------------------------------------------
command_not_found_handle() {
    local cmd="${1-}" pkg cand
    [ -n "$cmd" ] || return 127
    printf 'bash: %s: command not found\n' "$cmd" >&2

    if ! command -v apt-cache >/dev/null 2>&1; then
        printf '  （非 APT 系统，无法自动查询软件包）\n' >&2
        return 127
    fi
    # 只接受常规命令名，避免特殊字符被 apt-cache 当成正则
    if ! printf '%s' "$cmd" | grep -Eq '^[A-Za-z0-9._+-]+$'; then
        return 127
    fi

    pkg=$(apt-cache pkgnames "$cmd" 2>/dev/null | grep -x -F -- "$cmd" | head -n 1)
    if [ -n "$pkg" ]; then
        printf '\n  软件包 %s 可安装，执行：\n    sudo apt install %s\n\n' "$pkg" "$cmd" >&2
        return 127
    fi

    cand=$(apt-cache search "$cmd" 2>/dev/null | head -n 5)
    if [ -n "$cand" ]; then
        printf '\n  没有同名包，相近候选：\n' >&2
        printf '%s\n' "$cand" | sed 's/^/    /' >&2
        printf '\n  用 sudo apt install <包名> 安装。\n\n' >&2
        return 127
    fi

    if [ -z "$(ls -A /var/lib/apt/lists 2>/dev/null | grep -Ev '^(lock|partial|auxfiles)$')" ]; then
        printf '\n  APT 索引为空，先执行：sudo apt update\n\n' >&2
    else
        printf '\n  APT 中未找到相关包，可尝试：apt search %s\n\n' "$cmd" >&2
    fi
    return 127
}
export -f command_not_found_handle 2>/dev/null
PAYLOAD
}

print_hook() {
cat <<'HOOK'
# >>> shell-boost >>>
[ -r /etc/shell-boost.sh ] && . /etc/shell-boost.sh
# <<< shell-boost <<<
HOOK
}

# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------
strip_block() {
    local f="$1"
    [ -f "$f" ] || return 0
    grep -qF "$MARK_BEGIN" "$f" 2>/dev/null || return 0
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
        $0 == b { skip = 1; next }
        $0 == e { skip = 0; next }
        skip != 1 { print }
    ' "$f" > "${f}.sbnew" && mv "${f}.sbnew" "$f"
}

backup() {
    local f="$1"
    [ -f "$f" ] || return 0
    local bak="${f}.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a "$f" "$bak" 2>/dev/null && printf '%s\n' "$bak"
}

write_hook() {
    local f="$1" bak
    [ -e "$f" ] || : > "$f" 2>/dev/null || { c_warn "无法创建 $f"; return 1; }
    # 仅在首次注入时备份；重复执行不再产生备份堆叠
    if ! grep -qF "$MARK_BEGIN" "$f" 2>/dev/null; then
        bak=$(backup "$f")
        [ -n "$bak" ] && [ -s "$f" ] && c_info "已备份：$bak"
    fi
    strip_block "$f"
    # 文件末尾若无换行则补一个，避免钩子粘在用户最后一行后面
    if [ -s "$f" ] && [ -n "$(tail -c 1 "$f" 2>/dev/null)" ]; then
        printf '\n' >> "$f"
    fi
    print_hook >> "$f" || { c_warn "写入失败：$f"; return 1; }
    return 0
}

# 取用户数据库：优先 getent（支持 LDAP/SSSD），退化到 /etc/passwd
_passwd_dump() {
    if command -v getent >/dev/null 2>&1; then
        getent passwd 2>/dev/null
    else
        cat /etc/passwd 2>/dev/null
    fi
}

# 枚举真实用户：UID>=1000 且 shell 为 bash
list_bash_users() {
    _passwd_dump | awk -F: '
        $3 >= 1000 && $3 < 65534 && $6 != "" && $7 ~ /bash$/ { print $1 ":" $6 }
    '
}

list_nonbash_users() {
    _passwd_dump | awk -F: '
        $3 >= 1000 && $3 < 65534 && $7 != "" && $7 !~ /(bash|nologin|false)$/ { print $1 ":" $7 }
    '
}

# ---------------------------------------------------------------------------
if [ "$DRY_RUN" = 1 ]; then
    c_info "仅预览，不写入任何文件"
    printf '\n===== %s =====\n' "$PAYLOAD"
    print_payload
    printf '\n===== 系统级钩子（写入 %s / %s / %s）=====\n' "$SYSTEM_RC" "$PROFILE_D" "$SKEL"
    print_hook
    printf '\n===== 用户级钩子（追加到每个 bash 用户的 ~/.bashrc 末尾）=====\n'
    if [ "$SYSTEM_ONLY" = 1 ]; then
        printf '（--system-only，跳过用户家目录）\n'
    else
        list_bash_users | while IFS=: read -r u h; do
            printf '  %-16s %s/.bashrc\n' "$u" "$h"
        done
    fi
    exit 0
fi

need_root

# ---------------------------------------------------------------------------
if [ "$UNINSTALL" = 1 ]; then
    printf '\033[36m== 卸载 shell-boost ==\033[0m\n'
    for f in "$SYSTEM_RC" "$PROFILE_D" "$SKEL"; do
        if [ -f "$f" ] && grep -qF "$MARK_BEGIN" "$f" 2>/dev/null; then
            strip_block "$f" && c_ok "已清理钩子：$f"
        fi
    done
    if [ "$SYSTEM_ONLY" = 0 ]; then
        list_bash_users | while IFS=: read -r u h; do
            f="$h/.bashrc"
            if [ -n "$h" ] && [ -f "$f" ] && grep -qF "$MARK_BEGIN" "$f" 2>/dev/null; then
                strip_block "$f" && c_ok "已清理钩子：$f（用户 $u）"
            fi
        done
    fi
    if [ -f "$PROFILE_D" ] && ! grep -qF "$MARK_BEGIN" "$PROFILE_D" 2>/dev/null; then
        rm -f "$PROFILE_D" && c_ok "已删除 $PROFILE_D"
    fi
    if [ -f "$PAYLOAD" ]; then
        rm -f "$PAYLOAD" && c_ok "已删除 $PAYLOAD"
    fi
    c_ok "卸载完成，重开终端生效"
    exit 0
fi

printf '\033[36m== Debian shell-boost 安装（全系统）==\033[0m\n'

if ! command -v apt-get >/dev/null 2>&1; then
    c_err "未检测到 apt-get，这不是 Debian/Ubuntu 系统。"
    exit 1
fi
c_ok "检测到 APT 系统"

# ---- 依赖 -----------------------------------------------------------------
if [ "$DO_DEPS" = 1 ]; then
    if dpkg -s bash-completion >/dev/null 2>&1; then
        c_ok "bash-completion 已安装"
    else
        c_info "正在安装 bash-completion ..."
        if apt-get install -y bash-completion >/dev/null 2>&1; then
            c_ok "bash-completion 安装完成"
        else
            c_warn "bash-completion 安装失败（无外网或源未更新）"
            c_warn "ll 与命令提示仍可用，但子命令 Tab 补全不可用"
            c_warn "手动重试：apt update && apt install -y bash-completion"
        fi
    fi
    if [ ! -r /usr/share/bash-completion/bash_completion ] \
       && [ ! -r /etc/bash_completion ]; then
        c_warn "补全框架文件缺失，Tab 补全可能不完整"
        c_warn "尝试修复：apt install --reinstall -y bash-completion"
    fi
fi

# ---- 1) 配置源 ------------------------------------------------------------
_new=$(mktemp) || exit 1
print_payload > "$_new"
if [ -f "$PAYLOAD" ]; then
    if cmp -s "$_new" "$PAYLOAD"; then
        c_ok "配置源内容未变：$PAYLOAD"
    else
        bak=$(backup "$PAYLOAD"); [ -n "$bak" ] && c_info "已备份：$bak"
    fi
fi
cp "$_new" "$PAYLOAD" && chmod 644 "$PAYLOAD" && rm -f "$_new" && c_ok "配置源已就位：$PAYLOAD"

# ---- 2) 系统级入口 --------------------------------------------------------
write_hook "$SYSTEM_RC" && c_ok "系统级钩子已写入 $SYSTEM_RC"

mkdir -p "$(dirname "$PROFILE_D")" 2>/dev/null
{
    printf '# >>> shell-boost >>>\n'
    printf '[ -r /etc/shell-boost.sh ] && . /etc/shell-boost.sh\n'
    printf '# <<< shell-boost <<<\n'
} > "$PROFILE_D" && chmod 644 "$PROFILE_D" && c_ok "登录 shell 入口已写入 $PROFILE_D"

# ---- 3) 新建用户模板 ------------------------------------------------------
if [ -d "$(dirname "$SKEL")" ]; then
    write_hook "$SKEL" && c_ok "新用户模板已写入 $SKEL"
else
    c_warn "未找到 /etc/skel，跳过新用户模板"
fi

# ---- 4) 每个现有 bash 用户 ------------------------------------------------
if [ "$SYSTEM_ONLY" = 1 ]; then
    c_info "--system-only：跳过现有用户家目录"
else
    printf '\n\033[36m== 注入现有用户 ~/.bashrc ==\033[0m\n'
    count=0
    while IFS=: read -r u h; do
        [ -n "$h" ] || continue
        if [ ! -d "$h" ]; then
            c_warn "$u：家目录不存在（$h），跳过"
            continue
        fi
        rc="$h/.bashrc"
        if write_hook "$rc"; then
            c_ok "$u → $rc"
            count=$((count + 1))
        fi
    done <<EOF
$(list_bash_users)
EOF
    c_info "共处理 $count 个用户"
fi

# ---- 5) 非 bash 用户提示 --------------------------------------------------
nonbash=$(list_nonbash_users)
if [ -n "$nonbash" ]; then
    printf '\n'
    c_warn "以下用户不是 bash，本次配置对其无效："
    printf '%s\n' "$nonbash" | while IFS=: read -r u sh; do
        printf '    %-16s %s\n' "$u" "$sh"
    done
    printf '    如需生效：usermod -s /bin/bash <用户名>（或自行配置 zsh/fish）\n'
fi

# ---- 6) 自检 --------------------------------------------------------------
printf '\n\033[36m== 自检 ==\033[0m\n'
[ -r "$PAYLOAD" ] && c_ok "配置源存在" || c_err "配置源缺失"
bash -n "$PAYLOAD" 2>/dev/null && c_ok "配置源语法正确" || c_err "配置源语法错误"

for f in "$SYSTEM_RC" "$PROFILE_D" "$SKEL"; do
    if [ -f "$f" ] && grep -qF 'shell-boost.sh' "$f" 2>/dev/null; then
        c_ok "钩子就位：$f"
    else
        c_warn "钩子缺失：$f"
    fi
done

out=$(bash -i -c 'alias ll >/dev/null 2>&1 && echo LL
                  declare -F _completion_loader >/dev/null 2>&1 && echo COMP
                  declare -F command_not_found_handle >/dev/null 2>&1 && echo CNF' 2>/dev/null)
case "$out" in *LL*)   c_ok "ll 别名生效" ;;         *) c_err "ll 别名未生效" ;; esac
case "$out" in *CNF*)  c_ok "命令未找到提示已注册" ;; *) c_err "命令提示未注册" ;; esac
case "$out" in *COMP*) c_ok "Tab 补全框架已加载" ;;   *) c_warn "Tab 补全框架未加载" ;; esac

cat <<'TIP'

完成。所有 bash 用户重开终端即生效，也可立即生效：

    exec bash

验证某个用户：
    su - <用户名> -c 'bash -ic "alias ll; declare -F command_not_found_handle"' 

注意：
    * 只对交互式 bash 生效；脚本、cron、systemd 里不会触发提示。
    * 已存在的用户不受影响，但新建用户会自动带上（通过 /etc/skel）。
    * 卸载：sudo bash debian-shell-boost.sh --uninstall
TIP
