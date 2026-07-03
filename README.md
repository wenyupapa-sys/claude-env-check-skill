# Claude Env Check Skill

A reusable Codex/OpenAI skill for auditing local Claude Code environment risk signals: proxy/VPN/TUN state, macOS system proxy visibility, timezone consistency, proxy environment variables, Anthropic/Claude base URL residue, exit IP, IPv6, and DNS leak heuristics.

The bundled checker is read-only. It prints findings and recommendations, but it does not modify timezone, proxy, shell, VPN, or app settings.

## Install

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

## Use

In Codex or another compatible agent, ask:

```text
Use $claude-env-check to audit my Claude Code proxy, timezone, DNS, and environment-variable risk.
```

You can also run the checker directly:

```bash
bash ~/.codex/skills/claude-env-check/scripts/claude-env-check.sh
```

Offline mode skips network checks:

```bash
bash ~/.codex/skills/claude-env-check/scripts/claude-env-check.sh --offline
```

## What It Checks

- macOS and Node.js timezone surfaces
- macOS system proxy from `scutil --proxy`
- `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NODE_OPTIONS`, `ANTHROPIC_BASE_URL`, and `CLAUDE_CODE_BASE_URL`
- shell startup files and common tool configs for proxy/mirror residue
- local proxy processes and common proxy ports
- IPv4/IPv6 exit country and simple DNS leak heuristics
- BrowserLeaks and ipleak.net retest links

## Notes

This skill is a diagnostic aid, not a guarantee that an account or service will avoid risk controls. Browser-side checks still matter because a shell script cannot fully inspect browser WebRTC, TLS, HTTP, or profile-level behavior.

## License

MIT
