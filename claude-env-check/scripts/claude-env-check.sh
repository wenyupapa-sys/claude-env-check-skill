#!/usr/bin/env bash
# Claude Code local environment risk checker.
# Read-only by default. It does not change system or user config.

set -u

VERSION="2026-07-03"
OFFLINE=0

for arg in "$@"; do
  case "$arg" in
    --offline) OFFLINE=1 ;;
    -h|--help)
      cat <<'EOF'
Usage:
  bash claude-env-check.sh [--offline]

Checks:
  - System timezone as seen by Node.js and macOS
  - macOS system proxy visibility
  - Proxy / Claude / Anthropic environment variables
  - NODE_OPTIONS proxy flags that can break or fingerprint Node-based tools
  - Shell, npm, yarn, pnpm, Git, Homebrew, Claude config residues
  - Local proxy processes and ports
  - Exit IP, IPv6, DNS leak heuristics unless --offline is used
  - Browser-side retest links for BrowserLeaks / DNS leak tools

This script is read-only. It prints findings and suggested manual fixes.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED="$(printf '\033[31m')"
  GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"
  BLUE="$(printf '\033[34m')"
  BOLD="$(printf '\033[1m')"
  NC="$(printf '\033[0m')"
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  NC=""
fi

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
INFO_COUNT=0
RECOMMENDATIONS=""

section() {
  printf '\n%s%s%s\n' "$BOLD" "$1" "$NC"
  printf '%s\n' "----------------------------------------"
}

add_rec() {
  RECOMMENDATIONS="${RECOMMENDATIONS}
- $1"
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '%s[PASS]%s %s\n' "$GREEN" "$NC" "$1"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '%s[FAIL]%s %s\n' "$RED" "$NC" "$1"
}

info() {
  INFO_COUNT=$((INFO_COUNT + 1))
  printf '%s[INFO]%s %s\n' "$BLUE" "$NC" "$1"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

mask_value() {
  # Mask URL credentials and obvious secret-like values before printing.
  printf '%s' "$1" \
    | sed -E \
      -e 's#(://)[^/@]+@#\1***@#g' \
      -e 's#(://[^/:@]+:)[^/@]+@#\1***@#g' \
      -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1***#g' \
      -e 's#([A-Za-z_]*(TOKEN|KEY|SECRET|PASSWORD|AUTH)[A-Za-z_]*=)[^[:space:]]+#\1***#Ig'
}

print_cmd_output() {
  cmd_label="$1"
  output="$2"
  if [ -n "$output" ]; then
    printf '  %s\n' "$cmd_label"
    printf '%s\n' "$output" | while IFS= read -r line; do
      printf '    %s\n' "$(mask_value "$line")"
    done
  fi
}

json_field() {
  # Very small JSON field extractor for the simple ipinfo/dnsleaktest shapes.
  field="$1"
  sed -nE 's/.*"'$field'"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1
}

contains_china_provider() {
  printf '%s' "$1" | grep -qiE 'china|cn$|alibaba|aliyun|alicloud|tencent|qcloud|huawei|volces|bytedance|baidu|moonshot|minimax|stepfun|zhipu|siliconflow'
}

is_official_anthropic_url() {
  val="$1"
  [ -z "$val" ] && return 1
  printf '%s' "$val" | grep -qiE '^https://([^/]+\.)?anthropic\.com(/|$)|^https://api\.anthropic\.com(/|$)'
}

printf '%s\n' "========================================"
printf '%s\n' "Claude Code 环境一键体检 ($VERSION)"
printf '%s\n' "========================================"
printf '%s\n' "只读检查：不会修改系统、shell 或工具配置。"
if [ "$OFFLINE" -eq 1 ]; then
  printf '%s\n' "离线模式：跳过出口 IP / DNS 网络检测。"
fi

section "1. 系统与时区"

OS_NAME="$(uname -s 2>/dev/null || printf unknown)"
info "OS: $OS_NAME"

NODE_TZ=""
if has_cmd node; then
  NODE_SNIPPET='try { console.log(Intl.DateTimeFormat().resolvedOptions().timeZone || "") } catch (e) { process.exit(1) }'
  NODE_OUT="$(node -e "$NODE_SNIPPET" 2>&1)"
  NODE_STATUS=$?
  if [ "$NODE_STATUS" -eq 0 ] && [ -n "$NODE_OUT" ]; then
    NODE_TZ="$NODE_OUT"
    if printf '%s' "${NODE_TZ:-}" | grep -qE '^Asia/(Shanghai|Urumqi|Chongqing|Harbin)$'; then
      fail "Node.js 看到的时区是 ${NODE_TZ:-unknown}，命中 Claude Code 环境画像风险项。"
      add_rec "把 macOS/iPhone 时区改成目标地区，并关闭基于当前位置自动设置时区。"
    elif [ -n "${NODE_TZ:-}" ]; then
      pass "Node.js 看到的时区是 ${NODE_TZ:-unknown}，未命中中国时区。"
    else
      pass "Node.js 看到的时区是 ${NODE_TZ:-unknown}，未命中中国时区。"
    fi
  else
    warn "Node.js 存在，但无法读取 Intl 时区: $(mask_value "$(printf '%s' "$NODE_OUT" | head -1)")"
    if [ -n "${NODE_OPTIONS:-}" ]; then
      NODE_TZ_NO_OPTIONS="$(env -u NODE_OPTIONS node -e "$NODE_SNIPPET" 2>/dev/null || true)"
      if [ -n "$NODE_TZ_NO_OPTIONS" ]; then
        NODE_TZ="$NODE_TZ_NO_OPTIONS"
        if printf '%s' "$NODE_TZ_NO_OPTIONS" | grep -qE '^Asia/(Shanghai|Urumqi|Chongqing|Harbin)$'; then
          fail "清除 NODE_OPTIONS 后，Node.js 看到的时区是 $NODE_TZ_NO_OPTIONS，命中中国时区风险项。"
          add_rec "把 macOS/iPhone 时区改成目标地区，并关闭基于当前位置自动设置时区。"
        else
          info "清除 NODE_OPTIONS 后，Node.js 看到的时区是 $NODE_TZ_NO_OPTIONS。"
        fi
      fi
    fi
  fi
else
  warn "未安装 node，无法模拟 Claude Code 常用的 Intl 时区读取方式。"
fi

if [ "$OS_NAME" = "Darwin" ]; then
  SYS_TZ_RAW="$(systemsetup -gettimezone 2>&1 || true)"
  SYS_TZ="$(printf '%s' "$SYS_TZ_RAW" | sed -n 's/^Time Zone: //p')"
  if [ -n "$SYS_TZ" ]; then
    info "macOS systemsetup 时区: $SYS_TZ"
  elif [ -n "$SYS_TZ_RAW" ]; then
    info "macOS systemsetup 时区读取受限: $(printf '%s' "$SYS_TZ_RAW" | head -1)"
  fi
  LOCALTIME="$(readlink /etc/localtime 2>/dev/null || true)"
  if [ -n "$LOCALTIME" ]; then
    info "/etc/localtime -> $LOCALTIME"
    if [ -z "${NODE_TZ:-}" ] && printf '%s' "$LOCALTIME" | grep -qE '/Asia/(Shanghai|Urumqi|Chongqing|Harbin)$'; then
      fail "/etc/localtime 指向中国时区，且 Node.js 时区检测未成功。"
        add_rec "先处理 NODE_OPTIONS/Node.js 问题，再确认时区是否需要从 Asia/Shanghai 改到目标地区。"
    fi
  fi
fi

section "2. macOS 系统代理可见性"

if [ "$OS_NAME" = "Darwin" ] && has_cmd scutil; then
  PROXY_DUMP="$(scutil --proxy 2>/dev/null || true)"
  PROXY_ENABLED="$(printf '%s\n' "$PROXY_DUMP" | grep -E '^[[:space:]]*(HTTPEnable|HTTPSEnable|SOCKSEnable)[[:space:]]*:[[:space:]]*1' || true)"
  if [ -n "$PROXY_ENABLED" ]; then
    fail "macOS 系统代理当前是开启状态，应用可以直接读到 proxy 设置。"
    print_cmd_output "scutil --proxy 命中项:" "$(printf '%s\n' "$PROXY_DUMP" | grep -Ei 'HTTP|HTTPS|SOCKS|Proxy|Port' || true)"
    add_rec "如果你使用 TUN 模式，关闭 macOS 系统代理，让 scutil --proxy 里的 HTTPEnable/HTTPSEnable/SOCKSEnable 都是 0。"
  else
    pass "scutil --proxy 未发现 HTTP/HTTPS/SOCKS 系统代理开启。"
  fi
else
  info "非 macOS 或无 scutil，跳过系统代理检查。"
fi

section "3. 环境变量残留"

PROXY_VARS="ALL_PROXY all_proxy HTTP_PROXY http_proxy HTTPS_PROXY https_proxy FTP_PROXY ftp_proxy GOPROXY NO_PROXY no_proxy"
FOUND_PROXY_ENV=0
for var in $PROXY_VARS; do
  eval "val=\${$var:-}"
  if [ -n "$val" ]; then
    FOUND_PROXY_ENV=1
    if [ "$var" = "NO_PROXY" ] || [ "$var" = "no_proxy" ]; then
      info "$var=$(mask_value "$val")"
    elif [ "$var" = "GOPROXY" ]; then
      warn "$var=$(mask_value "$val")"
      add_rec "GOPROXY 不等于 HTTP proxy，但如果含 goproxy.cn 等中国域名，建议按需改成 direct 或官方/可信源。"
    else
      fail "$var=$(mask_value "$val")"
      add_rec "清理当前 shell 和启动文件里的 $var；TUN 模式下通常不需要显式 proxy 环境变量。"
    fi
  fi
done
[ "$FOUND_PROXY_ENV" -eq 0 ] && pass "未发现常见 proxy 环境变量。"

if [ -n "${NODE_OPTIONS:-}" ]; then
  if printf '%s' "$NODE_OPTIONS" | grep -qi 'proxy'; then
    fail "NODE_OPTIONS=$(mask_value "$NODE_OPTIONS")"
    add_rec "清理 shell 启动文件里的 NODE_OPTIONS proxy 参数；它可能让 Node 工具暴露代理意图，当前还会让本机 node 直接报错。"
  else
    info "NODE_OPTIONS=$(mask_value "$NODE_OPTIONS")"
  fi
fi

FOUND_ANTHROPIC_ENV=0
for var in $(env | sed -nE 's/^([^=]*(ANTHROPIC|CLAUDE)[^=]*)=.*/\1/Ip' | sort -u); do
  FOUND_ANTHROPIC_ENV=1
  eval "val=\${$var:-}"
  upper="$(printf '%s' "$var" | tr '[:lower:]' '[:upper:]')"
  if [ "$upper" = "ANTHROPIC_BASE_URL" ] || [ "$upper" = "CLAUDE_CODE_BASE_URL" ]; then
    if is_official_anthropic_url "$val"; then
      warn "$var=$(mask_value "$val")"
      add_rec "$var 已显式设置；即使是官方域名，也建议确认是否真的需要。"
    else
      fail "$var=$(mask_value "$val")"
      add_rec "重点清理 $var。第三方中转站或镜像站 base URL 是很强的可见信号。"
    fi
  elif printf '%s' "$upper" | grep -qE 'TOKEN|KEY|SECRET|AUTH'; then
    info "$var=(set, hidden)"
  else
    info "$var=$(mask_value "$val")"
  fi
done
[ "$FOUND_ANTHROPIC_ENV" -eq 0 ] && pass "当前 shell 未发现 Anthropic/Claude 相关环境变量。"

section "4. 启动文件与配置文件扫描"

SCAN_FILES="
$HOME/.zshrc
$HOME/.zprofile
$HOME/.zshenv
$HOME/.bashrc
$HOME/.bash_profile
$HOME/.profile
$HOME/.config/fish/config.fish
$HOME/.npmrc
$HOME/.yarnrc
$HOME/.yarnrc.yml
$HOME/.pnpmrc
$HOME/.gitconfig
$HOME/.claude/settings.json
$HOME/.claude/settings.local.json
$HOME/.claude.json
$HOME/.config/claude/settings.json
"

FOUND_FILE_HITS=0
for file in $SCAN_FILES; do
  if [ -f "$file" ]; then
    hits="$(grep -nEi 'proxy|base[_-]?url|baseUrl|anthropic[_-]?(base[_-]?url|api[_-]?key|auth[_-]?token)|ANTHROPIC_[A-Z0-9_]*(BASE|URL|KEY|TOKEN|AUTH)[A-Z0-9_]*|CLAUDE_CODE_BASE_URL|NODE_OPTIONS|aihubmix|openai-sb|mirror|goproxy\.cn|npmmirror|taobao' "$file" 2>/dev/null || true)"
    if [ -n "$hits" ]; then
      FOUND_FILE_HITS=1
      warn "配置文件命中: $file"
      printf '%s\n' "$hits" | while IFS= read -r line; do
        printf '    %s\n' "$(mask_value "$line")"
      done
    fi
  fi
done

if [ "$FOUND_FILE_HITS" -eq 0 ]; then
  pass "常见 shell / npm / Git / Claude 配置文件未扫到 proxy/base_url 关键字。"
else
  add_rec "逐个打开上面命中的文件，删除不再需要的 proxy、base_url、第三方中转站和镜像站配置。"
fi

section "5. 工具链代理配置"

TOOL_HITS=0
if has_cmd npm; then
  for key in proxy https-proxy registry; do
    out="$(npm config get "$key" 2>/dev/null || true)"
    case "$out" in
      ""|"undefined"|"null") ;;
      *)
        if [ "$key" = "registry" ] && ! printf '%s' "$out" | grep -qiE 'taobao|npmmirror|cn'; then
          info "npm $key=$(mask_value "$out")"
        else
          TOOL_HITS=1
          warn "npm $key=$(mask_value "$out")"
        fi
        ;;
    esac
  done
else
  info "未找到 npm。"
fi

if has_cmd pnpm; then
  for key in proxy https-proxy registry; do
    out="$(pnpm config get "$key" 2>/dev/null || true)"
    case "$out" in
      ""|"undefined"|"null") ;;
      *)
        if [ "$key" = "registry" ] && ! printf '%s' "$out" | grep -qiE 'taobao|npmmirror|cn'; then
          info "pnpm $key=$(mask_value "$out")"
        else
          TOOL_HITS=1
          warn "pnpm $key=$(mask_value "$out")"
        fi
        ;;
    esac
  done
fi

if has_cmd yarn; then
  for key in proxy https-proxy httpProxy httpsProxy registry; do
    out="$(yarn config get "$key" 2>/dev/null | tail -1 || true)"
    case "$out" in
      ""|"undefined"|"null") ;;
      *)
        if [ "$key" = "registry" ] && ! printf '%s' "$out" | grep -qiE 'taobao|npmmirror|cn'; then
          info "yarn $key=$(mask_value "$out")"
        else
          TOOL_HITS=1
          warn "yarn $key=$(mask_value "$out")"
        fi
        ;;
    esac
  done
fi

if has_cmd git; then
  git_proxy="$(git config --global --get-regexp '^(http|https)\..*proxy$|^(http|https)\.proxy$' 2>/dev/null || true)"
  if [ -n "$git_proxy" ]; then
    TOOL_HITS=1
    warn "Git global proxy 命中:"
    printf '%s\n' "$git_proxy" | while IFS= read -r line; do
      printf '    %s\n' "$(mask_value "$line")"
    done
  fi
else
  info "未找到 git。"
fi

if has_cmd brew; then
  brew_proxy="$(brew config 2>/dev/null | grep -iE 'proxy|HOMEBREW.*URL|mirror' || true)"
  if [ -n "$brew_proxy" ]; then
    TOOL_HITS=1
    warn "Homebrew proxy/mirror 命中:"
    printf '%s\n' "$brew_proxy" | while IFS= read -r line; do
      printf '    %s\n' "$(mask_value "$line")"
    done
  fi
fi

if [ "$TOOL_HITS" -eq 0 ]; then
  pass "npm/pnpm/yarn/Git/Homebrew 未发现明显 proxy 或中国镜像配置。"
else
  add_rec "清理工具链配置：npm/pnpm/yarn proxy、Git http.proxy/https.proxy、Homebrew proxy/mirror。"
fi

section "6. 本地代理进程与端口"

PROC_HITS="$(pgrep -fl 'clash|mihomo|surge|v2ray|v2rayN|xray|sing-box|hysteria|trojan|shadowsocks|ss-local' 2>/dev/null || true)"
if [ -n "$PROC_HITS" ]; then
  info "发现代理相关进程:"
  printf '%s\n' "$PROC_HITS" | while IFS= read -r line; do
    printf '    %s\n' "$(mask_value "$line")"
  done
else
  info "未发现常见代理进程名。"
fi

PORT_HITS=""
if has_cmd lsof; then
  for port in 7890 7891 7892 1080 10808 20170 6152 9090 52549; do
    hit="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | tail -n +2 || true)"
    [ -n "$hit" ] && PORT_HITS="${PORT_HITS}
$hit"
  done
fi

if [ -n "$PORT_HITS" ]; then
  info "发现常见本地代理端口监听:"
  printf '%s\n' "$PORT_HITS" | sed '/^[[:space:]]*$/d' | while IFS= read -r line; do
    printf '    %s\n' "$(mask_value "$line")"
  done
  info "端口监听本身不一定有问题；关键是系统代理和环境变量不要指向它。"
else
  info "未发现常见本地代理端口监听。"
fi

if [ "$OS_NAME" = "Darwin" ]; then
  UTUNS="$(ifconfig 2>/dev/null | sed -nE 's/^(utun[0-9]+):.*/\1/p' | tr '\n' ' ')"
  [ -n "$UTUNS" ] && info "检测到 utun 接口: $UTUNS"
  ROUTES="$(netstat -rn 2>/dev/null | grep -E '^(default|0/1|128\.0/1|0\.0\.0\.0/1)' | head -8 || true)"
  [ -n "$ROUTES" ] && print_cmd_output "路由表摘要:" "$ROUTES"
fi

section "7. 出口 IP / IPv6 / DNS"

if [ "$OFFLINE" -eq 1 ]; then
  info "已跳过网络检测。"
else
  if has_cmd curl; then
    IPV4_JSON="$(curl -sS -4 --max-time 10 https://ipinfo.io/json 2>/dev/null || true)"
    if [ -n "$IPV4_JSON" ]; then
      IPV4_IP="$(printf '%s' "$IPV4_JSON" | json_field ip)"
      IPV4_COUNTRY="$(printf '%s' "$IPV4_JSON" | json_field country)"
      IPV4_ORG="$(printf '%s' "$IPV4_JSON" | json_field org)"
      IPV4_HOSTNAME="$(printf '%s' "$IPV4_JSON" | json_field hostname)"
      if [ "$IPV4_COUNTRY" = "CN" ]; then
        fail "IPv4 出口在 CN: $IPV4_IP $IPV4_ORG"
        add_rec "切换到目标地区出口后重测；如果目标画像是美国用户，建议固定为 US 出口。"
      elif [ "$IPV4_COUNTRY" = "US" ]; then
        pass "IPv4 出口在 US: $IPV4_IP $IPV4_ORG"
      elif [ -n "$IPV4_COUNTRY" ]; then
        warn "IPv4 出口不是 CN，但也不是 US: $IPV4_IP country=$IPV4_COUNTRY org=$IPV4_ORG"
        add_rec "如果你的目标画像是美国用户，出口国家建议固定为 US。"
      else
        warn "IPv4 出口 IP 返回异常，无法解析国家。"
      fi
      if contains_china_provider "$IPV4_ORG $IPV4_HOSTNAME"; then
        fail "IPv4 ASN/hostname 疑似含中国服务商特征: $(mask_value "$IPV4_ORG $IPV4_HOSTNAME")"
        add_rec "避免使用阿里云、腾讯云、华为云、火山等国内厂商海外节点作为最终出口。"
      fi
    else
      warn "IPv4 ipinfo.io 请求失败。"
    fi

    IPV6_JSON="$(curl -sS -6 --max-time 8 https://ipinfo.io/json 2>/dev/null || true)"
    if [ -n "$IPV6_JSON" ]; then
      IPV6_IP="$(printf '%s' "$IPV6_JSON" | json_field ip)"
      IPV6_COUNTRY="$(printf '%s' "$IPV6_JSON" | json_field country)"
      IPV6_ORG="$(printf '%s' "$IPV6_JSON" | json_field org)"
      if [ -n "$IPV6_IP" ] && ! printf '%s' "$IPV6_IP" | grep -q ':'; then
        warn "IPv6 测试返回的不是 IPv6 地址，可能被本地代理转换成 IPv4 出口: $IPV6_IP $IPV6_ORG"
        add_rec "用浏览器打开 https://browserleaks.com/ip 复测 IPv6 Leak Test；脚本层的 curl -6 可能被本地代理接管。"
      elif [ "$IPV6_COUNTRY" = "CN" ]; then
        fail "IPv6 出口在 CN，存在 IPv6 泄漏风险: $IPV6_IP $IPV6_ORG"
        add_rec "关闭 IPv6 或确保 IPv6 也走同一代理/VPN/TUN 出口。"
      elif [ "$IPV6_COUNTRY" = "US" ]; then
        pass "IPv6 出口在 US: $IPV6_IP $IPV6_ORG"
      elif [ -n "$IPV6_COUNTRY" ]; then
        warn "IPv6 可用但出口不是 US: $IPV6_IP country=$IPV6_COUNTRY org=$IPV6_ORG"
        add_rec "确认 IPv6 出口和 IPv4 出口画像一致；不需要 IPv6 时可关闭。"
      else
        warn "IPv6 可用，但无法解析国家。"
      fi
    else
      pass "IPv6 直连测试不可用或被代理关闭；通常可降低 IPv6 泄漏风险。"
    fi

    DNS_JSON="$(curl -sS --max-time 10 https://dnsleaktest.com/api/servers 2>/dev/null | head -c 20000 || true)"
    if [ -n "$DNS_JSON" ]; then
      if printf '%s' "$DNS_JSON" | grep -qiE 'china|中国|beijing|shanghai|guangzhou|shenzhen|hangzhou|tencent|alibaba|aliyun|huawei|baidu|"country"[[:space:]]*:[[:space:]]*"CN"'; then
        fail "DNS 泄漏测试疑似出现中国 DNS/服务商。"
        printf '%s\n' "$DNS_JSON" | head -c 1200 | sed 's/^/    /'
        printf '\n'
        add_rec "检查代理客户端 DNS 设置，启用远端 DNS/DoH/DoT，并避免系统 DNS 直连国内运营商。"
      else
        pass "dnsleaktest.com API 未发现明显中国 DNS 关键词。"
      fi
    else
      warn "DNS 泄漏 API 请求失败；建议再用浏览器打开 dnsleaktest.com 或 browserleaks.com/dns 复测。"
    fi
  else
    warn "未找到 curl，无法做出口 IP / DNS 网络检测。"
  fi
fi

section "8. 浏览器复测入口"

info "BrowserLeaks IP: https://browserleaks.com/ip"
info "BrowserLeaks DNS: https://browserleaks.com/dns"
info "BrowserLeaks WebRTC: https://browserleaks.com/webrtc"
info "备用综合检测: https://ipleak.net/"
info "备用 DNS 检测: https://dnsleaktest.com/"
printf '%s\n' "建议用你平时登录 Claude/Claude Code 相关网页的同一个浏览器打开；浏览器侧能看到 WebRTC、DNS、TLS/HTTP 指纹，脚本只能覆盖命令行和系统配置。"

section "9. 总结"

printf 'PASS: %s  WARN: %s  FAIL: %s  INFO: %s\n' "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "$INFO_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  printf '%s%s%s\n' "$RED" "结论：存在高风险项，建议先处理 FAIL 再使用 Claude Code。" "$NC"
elif [ "$WARN_COUNT" -gt 0 ]; then
  printf '%s%s%s\n' "$YELLOW" "结论：没有高风险项，但有若干可疑残留需要确认。" "$NC"
else
  printf '%s%s%s\n' "$GREEN" "结论：未发现明显本机环境风险项。" "$NC"
fi

if [ -n "$RECOMMENDATIONS" ]; then
  printf '\n%s\n' "建议处理清单:"
  printf '%s\n' "$RECOMMENDATIONS" | sed '/^[[:space:]]*$/d'
fi

printf '\n%s\n' "补充：这个脚本只能检查本机/网络侧可见信号，不能保证任何账号不会被风控或封禁。"
