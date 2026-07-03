# Claude Code Environment Risk Signals

## Timezone

Check all three surfaces:

- `date '+%Y-%m-%d %H:%M:%S %Z %z'`
- `readlink /etc/localtime`
- `node -e 'console.log(Intl.DateTimeFormat().resolvedOptions().timeZone)'`

On macOS, the visible automatic timezone switch is:

```bash
defaults read /Library/Preferences/com.apple.timezone.auto
```

The `timed` service may also store automatic timezone state under:

```text
/private/var/db/timed/Library/Preferences/com.apple.timed.plist
```

When fixing repeated timezone drift, turn off automatic timezone and set the desired zone with `systemsetup -settimezone <IANA zone>`. This needs administrator privileges. Automatic time sync and automatic timezone are separate settings; time sync can stay enabled while automatic timezone stays disabled.

## macOS System Proxy

`scutil --proxy` exposes system proxy settings to local apps. If HTTP/HTTPS/SOCKS are enabled, apps can observe values such as `127.0.0.1:10808`.

For TUN-first setups, the cleaner target state is usually:

- TUN routes command-line traffic through the intended exit.
- `scutil --proxy` shows `HTTPEnable`, `HTTPSEnable`, and `SOCKSEnable` as `0`.
- `curl --noproxy '*' https://ipinfo.io/json` still shows the intended exit country.

Do not assume system proxy off is safe until TUN is verified. If TUN is not actually routing traffic, disabling system proxy can expose direct traffic.

## TUN And Route Checks

Use route probes, not only GUI toggles:

```bash
route -n get 1.1.1.1
route -n get 8.8.8.8
curl --noproxy '*' -sS https://ipinfo.io/json
```

If the route interface is physical (`en0`, `en11`, etc.) and the raw curl exit is local/CN while proxied curl is US, TUN is not fully effective. If the route interface is `utun*` and raw curl is US, TUN is likely effective.

Multiple proxy cores can conflict. Before stopping anything, list exact paths:

```bash
ps -eo pid,user,ppid,stat,etime,command | awk '/v2rayN|sing-box|xray/ {print}'
```

Stop only processes whose path clearly belongs to the app being fixed. Avoid killing unrelated VPNs.

## Environment Variables

High-signal residues:

- `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, lowercase variants
- `NODE_OPTIONS=--use-env-proxy`
- `ANTHROPIC_BASE_URL`, `CLAUDE_CODE_BASE_URL`
- obvious third-party proxy, relay, or mirror hostnames in shell startup files

`NO_PROXY` is not itself a proxy route, but may reveal bypass policy. Report it as informational unless it causes routing bugs.

## Browser-Side Retest

Script checks do not fully simulate browser behavior. Ask the user to retest with the same browser/profile used for Claude:

- https://browserleaks.com/ip
- https://browserleaks.com/dns
- https://browserleaks.com/webrtc
- https://ipleak.net/

Interpret browser results together with command-line results. Browser OK + command-line direct means CLI tools such as Claude Code may still be exposed.

## Safe Restore Tooling

When creating restore scripts for proxy apps:

- Snapshot app config and helper scripts, not logs or stored passwords.
- Exclude `.sudo_pass`, `*.log`, `*.err`, and throwaway `configTest*.json` unless explicitly needed.
- Before restore, create a timestamped backup of current config.
- Restore generated configs only if the app expects them; otherwise prefer restoring source GUI config/database and let the app regenerate runtime files.
