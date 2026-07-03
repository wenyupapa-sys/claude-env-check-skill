# Claude Env Check

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Claude Env Check is a read-only local diagnostic tool and Codex skill for auditing Claude Code environment risk signals: proxy/VPN/TUN state, macOS system proxy visibility, timezone consistency, proxy environment variables, Anthropic/Claude base URL residue, exit IP, IPv6, and DNS leak heuristics.

Product page: https://wenyupapa-sys.github.io/claude-env-check-skill/

The checker prints findings and recommendations. It does not modify timezone, proxy, shell, VPN, or app settings.

## Install

One-line install:

```bash
curl -fsSL https://raw.githubusercontent.com/wenyupapa-sys/claude-env-check-skill/main/install.sh | bash
```

Or install from a cloned checkout:

```bash
git clone https://github.com/wenyupapa-sys/claude-env-check-skill.git
cd claude-env-check-skill
./install.sh
```

By default this installs to:

```text
~/.codex/skills/claude-env-check
```

Set `CODEX_SKILLS_DIR` if your skills directory is elsewhere:

```bash
CODEX_SKILLS_DIR="$HOME/.agents/skills" ./install.sh
```

The installer also creates a CLI at `~/.local/bin/claude-env-check` when possible. Add this to your shell profile if `~/.local/bin` is not already on `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Use As A CLI

```bash
claude-env-check
```

Offline mode skips network checks:

```bash
claude-env-check --offline
```

Without installing the CLI:

```bash
bash ~/.codex/skills/claude-env-check/scripts/claude-env-check.sh
```

## Use As A Codex Skill

In Codex or another compatible agent, ask:

```text
Use $claude-env-check to audit my Claude Code proxy, timezone, DNS, and environment-variable risk.
```

## What It Checks

- macOS and Node.js timezone surfaces
- macOS system proxy from `scutil --proxy`
- `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NODE_OPTIONS`, `ANTHROPIC_BASE_URL`, and `CLAUDE_CODE_BASE_URL`
- shell startup files and common tool configs for proxy/mirror residue
- local proxy processes and common proxy ports
- IPv4/IPv6 exit country and simple DNS leak heuristics
- BrowserLeaks and ipleak.net retest links

## Example Output

```text
PASS: Node.js timezone is America/Los_Angeles
FAIL: macOS system proxy is enabled at 127.0.0.1:10808
WARN: Homebrew mirror points to a regional mirror
INFO: Browser retest links for BrowserLeaks and ipleak.net
```

## Notes

This is a diagnostic aid, not a guarantee that an account or service will avoid risk controls. Browser-side checks still matter because a shell script cannot fully inspect browser WebRTC, TLS, HTTP, or profile-level behavior.

## Contributing

Bug reports, false positives, new platform checks, and clearer remediation guidance are welcome. Please keep the checker read-only by default.

## License

MIT
