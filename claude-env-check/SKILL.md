---
name: claude-env-check
description: Audit and troubleshoot local Claude Code environment risk signals, especially proxy/VPN/TUN state, macOS system proxy visibility, timezone consistency, NODE_OPTIONS/proxy environment variables, Anthropic/Claude base URL residues, exit IP, IPv6, and DNS leak checks. Use when the user asks to check whether Claude Code is safe/clean to use, diagnose proxy or TUN problems, verify BrowserLeaks/ipinfo results, fix repeated timezone changes, or create a one-command local environment check.
---

# Claude Env Check

## Quick Start

Run the bundled checker first unless the user asks only for explanation:

```bash
bash "${SKILL_DIR}/scripts/claude-env-check.sh"
```

Replace `${SKILL_DIR}` with the absolute path to this skill folder. Use offline mode when network calls are undesirable:

```bash
bash "${SKILL_DIR}/scripts/claude-env-check.sh" --offline
```

The script is read-only. It checks local state and prints findings; it does not change time zone, proxy, shell config, or app settings.

## Workflow

1. **Run the checker.** Prefer the script output over ad hoc commands because it masks common secrets and checks the same surfaces consistently.
2. **Summarize the result by severity.** Lead with `FAIL` items, then `WARN`; avoid implying that any check guarantees account safety.
3. **Classify the issue.**
   - Timezone risk: Node.js or `/etc/localtime` reports a China timezone, or automatic timezone is enabled.
   - System proxy risk: `scutil --proxy` exposes HTTP/HTTPS/SOCKS proxy settings such as `127.0.0.1:10808`.
   - Environment residue: shell has `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NODE_OPTIONS=--use-env-proxy`, `ANTHROPIC_BASE_URL`, or `CLAUDE_CODE_BASE_URL`.
   - TUN/proxy mismatch: browser or proxied curl shows US, but `curl --noproxy '*' https://ipinfo.io/json` or route checks still go direct.
   - DNS/IPv6 leak: DNS provider or IPv6 country/ASN conflicts with the intended exit profile.
4. **Verify browser-side separately.** Ask the user to open these in the same browser/profile used for Claude:
   - https://browserleaks.com/ip
   - https://browserleaks.com/dns
   - https://browserleaks.com/webrtc
   - https://ipleak.net/
5. **Only change settings after explaining impact.** macOS system proxy, v2rayN TUN, and timezone settings can affect all apps. Prefer reversible commands and take backups before editing config files.

## Common Follow-Up Commands

Use these for targeted investigation after the script points to a problem:

```bash
date '+%Y-%m-%d %H:%M:%S %Z %z'
readlink /etc/localtime
defaults read /Library/Preferences/com.apple.timezone.auto
node -e 'console.log(Intl.DateTimeFormat().resolvedOptions().timeZone)'
```

```bash
scutil --proxy
curl -sS https://ipinfo.io/json
curl --noproxy '*' -sS https://ipinfo.io/json
route -n get 1.1.1.1
route -n get 8.8.8.8
```

```bash
env | sort | rg '^(NODE_OPTIONS|http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|all_proxy|NO_PROXY|no_proxy|ANTHROPIC|CLAUDE)='
```

## Fix Guidance

For detailed signals and repair cautions, read `references/risk-signals.md` when the user asks why a finding matters or wants you to fix it.

Keep fixes conservative:

- Do not delete or overwrite user proxy/VPN configs without backing them up.
- Avoid killing unrelated VPNs; filter process paths before stopping proxy cores.
- Avoid leaving temporary TUN configs, root `sing-box` processes, or modified v2rayN generated scripts behind.
- If creating restore tooling, include a backup step and exclude logs, stored sudo passwords, and throwaway test configs.
