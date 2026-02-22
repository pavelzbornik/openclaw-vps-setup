---
name: openclaw-expert
description: "Expert knowledge base for OpenClaw — the open-source autonomous AI agent gateway (openclaw/openclaw, TypeScript, MIT). Use this skill whenever the user asks questions about OpenClaw architecture, config, workspace files (SOUL.md, AGENTS.md, HEARTBEAT.md, etc.), credentials, security hardening, Ansible deployment, backup/migration, or troubleshooting gateway issues. Trigger on any mention of 'openclaw', 'gateway config', 'openclaw.json', 'SOUL.md', 'heartbeat', 'openclaw backup', or any question about deploying or configuring the agent. Key facts are embedded in this skill so answers are accurate without needing external search."
---

# OpenClaw Expert

## What OpenClaw Is

OpenClaw (`openclaw/openclaw`) is a **self-hosted AI agent gateway** — a persistent
Node.js (≥22) daemon that:

- Connects to 12+ messaging platforms (WhatsApp, Telegram, Discord, Slack, Signal,
  iMessage via BlueBubbles, Google Chat, Teams, Matrix, LINE, and more)
- Routes conversations to LLM providers (Anthropic, OpenAI, Gemini, OpenRouter,
  Ollama, and 15+ more)
- Runs autonomous **heartbeat cycles** (every 30 min by default) to check inboxes,
  calendars, and tasks
- Executes tools and skills — browsing the web, managing files, sending messages,
  running code
- Maintains agent identity through a **file-based workspace system** (Markdown files
  in `~/.openclaw/workspace/`)

The central process is called the **Gateway**, which multiplexes WebSocket RPC,
HTTP API, and static UI on a single port (default **18789**). The web Control UI
lives at `http://127.0.0.1:18789/`.

**Do not confuse** with `pjasicek/OpenClaw` (~400 stars), a C++ Captain Claw
game reimplementation with no server component.

---

## Architecture at a Glance

```text
~/.openclaw/
├── openclaw.json          # Main config (JSON5 format)
├── .env                   # API keys and env vars (chmod 600)
├── credentials/           # OAuth tokens, service account files (chmod 700)
├── agents/
│   └── <agentId>/
│       └── sessions/      # JSONL conversation transcripts
└── workspace/
    ├── SOUL.md            # Agent personality & values
    ├── AGENTS.md          # Operating instructions & memory protocol
    ├── USER.md            # User profile & preferences
    ├── IDENTITY.md        # Name, emoji, avatar
    ├── TOOLS.md           # Local tool notes & SSH hosts
    ├── HEARTBEAT.md       # Periodic check checklist (runs 48x/day)
    ├── BOOT.md            # Gateway restart ritual (optional)
    ├── BOOTSTRAP.md       # First-run onboarding (self-deletes after)
    ├── MEMORY.md          # Curated long-term memory
    ├── memory/
    │   └── YYYY-MM-DD.md  # Daily append-only logs
    └── skills/
        └── <name>/SKILL.md
```

**Port map:**

| Port  | Purpose                          |
|-------|----------------------------------|
| 18789 | Gateway main (WS + HTTP + UI)    |
| 18791 | Browser CDP control (port + 2)   |
| 18793 | Canvas Host HTTP (port + 4)      |
| 5353  | mDNS discovery (disable in prod) |

---

## Workspace Files: What Each One Does

All workspace files are injected into the system prompt at session start.
Every word costs tokens — keep files tight and opinionated.

### SOUL.md
The **behavioral core**. Loaded every session. Recommended: 50–100 lines max.
Structure: Core Truths → Communication Style → Values → Boundaries → Continuity.

The agent can and should modify its own SOUL.md, but must notify the user.
Anti-patterns: contradictory instructions, vague directives ("be helpful"),
files over 150 lines.

### AGENTS.md
The **operating manual**. Primary instruction file (~200 lines is fine).
Covers: boot sequence (read SOUL → USER → today/yesterday memory → MEMORY.md),
memory protocol, safety rules, group chat behavior, heartbeat vs. cron guidance.

Critical rule to include: *"Memory is limited — if you want to remember
something, WRITE IT TO A FILE. Mental notes don't survive session restarts."*

### USER.md
**Personal context**: name, timezone, location, language preferences, family
schedule, work context, communication channels, style preferences, pet peeves.
The agent should update USER.md itself as it learns new things.

### IDENTITY.md
**Presentation layer**: name (prefix on group chat messages), creature type,
vibe (one-liner), emoji (used for acknowledgment reactions), avatar path.
Applied via `openclaw agents set-identity --from-identity`.

### TOOLS.md
**Environment-specific cheat sheet** — SSH host aliases, Home Assistant entity
IDs and URL, project locations, shell conventions, device nicknames.
Does NOT control which tools exist; that's SKILL.md files.

### HEARTBEAT.md
Runs every 30 min (default). If nothing needs attention → `HEARTBEAT_OK`
(gateway silently drops it). **Empty file = skips the API call entirely.**
Recommended: 5–10 lines max. Use cheap model (Haiku vs. Opus = $0.005/day vs.
$0.24/day at 48 runs). Always set `activeHours` to avoid nighttime pings.

### BOOT.md
Runs on every gateway restart. Requires `hooks.internal.enabled: true` +
`openclaw hooks enable boot-md`. Keep tasks idempotent (bug #9167: BOOT.md
can fire multiple times during startup).

### BOOTSTRAP.md
One-time first-run onboarding — discovers name, identity, fills workspace files,
then **self-deletes**. First message must be "Read BOOTSTRAP.md and walk me
through it" or agent may skip it. Skip with `agent.skipBootstrap: true`.

---

## openclaw.json: Key Fields

Written in **JSON5** (comments, trailing commas, unquoted keys allowed).
Gateway hot-reloads changes except: port, bind, auth, TLS (require restart).

```json5
{
  gateway: {
    port: 18789,
    bind: "loopback",          // CRITICAL: never "lan" on public servers
    trustedProxies: ["127.0.0.1"],  // Required when behind Nginx
    auth: {
      mode: "token",
      token: "${OPENCLAW_GATEWAY_TOKEN}",
    },
    mdns: { enabled: false },  // Disable in production
  },
  agents: {
    defaults: {
      model: {
        primary: "anthropic/claude-sonnet-4-5",
        fallbacks: ["openrouter/anthropic/claude-sonnet-4-5"],
      },
      heartbeat: { every: "30m", target: "last" },
      sandbox: {
        mode: "non-main",      // Sandbox group chats, not DMs
        docker: { network: "none", readOnlyRoot: true, capDrop: ["ALL"] },
      },
    },
  },
  models: {
    providers: {
      // ⚠️ ${ENV_VAR} inline keys leak into prompt context (issue #11202) — prefer auth profiles or keychain
      anthropic: { apiKey: "${ANTHROPIC_API_KEY}" },
    },
  },
  channels: {
    telegram: { enabled: true, botToken: "${TELEGRAM_BOT_TOKEN}", dmPolicy: "pairing" },
  },
}
```

**Bind modes:**
- `loopback` — binds to `127.0.0.1`, default, most secure
- `lan` — binds `0.0.0.0`, mandates auth
- `tailnet` — binds to Tailscale IP only
- `auto` — tries loopback → tailnet → lan

---

## Credentials Reference

### LLM Providers

| Provider     | Env Var                                    |
|--------------|--------------------------------------------|
| Anthropic    | `ANTHROPIC_API_KEY`                        |
| OpenAI       | `OPENAI_API_KEY`                           |
| Google       | `GEMINI_API_KEY`                           |
| OpenRouter   | `OPENROUTER_API_KEY`                       |
| AWS Bedrock  | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` + `AWS_REGION` |
| Ollama       | `OLLAMA_BASE_URL` (no key needed)          |

### Messaging Channels

| Channel   | Credential                            |
|-----------|---------------------------------------|
| Telegram  | `TELEGRAM_BOT_TOKEN` (via @BotFather) |
| Discord   | `DISCORD_BOT_TOKEN`                   |
| Slack     | `SLACK_BOT_TOKEN` + `SLACK_APP_TOKEN` |
| WhatsApp  | QR code pairing (no API key)          |

### Storage Best Practices
Prefer **OS keychain** (`openclaw configure set-key anthropic sk-ant-...`)
over env vars over inline JSON. Known issue #11202: `${ENV_VAR}` substitutions
can leak keys into LLM prompt context — use auth profiles or keychain instead.

---

## Security Hardening

**Five-layer architecture for LAN home lab:**

1. **UFW** — deny all incoming; allow SSH + HTTPS (443) + Tailscale from LAN subnet only; explicitly `deny` port 18789
2. **Nginx** — TLS termination (self-signed for LAN), IP restriction `allow 192.168.0.0/16`, rate limit 10r/s, WebSocket upgrade headers, 86400s timeouts
3. **Docker** — bind gateway port to `127.0.0.1:18789:18789` only; `read_only: true`, `cap_drop: ALL`, `no-new-privileges: true`, non-root `node` user (uid 1000)
4. **Gateway** — `bind: loopback`, `trustedProxies: ["127.0.0.1"]`, `auth.mode: "token"`, `mdns.enabled: false`, `controlUi.dangerouslyDisableDeviceAuth: false`
5. **Tailscale** — for remote access: `gateway.tailscale.mode: "serve"` replaces Nginx for remote; keeps loopback for LAN

**Critical Nginx header:** Use `proxy_set_header X-Forwarded-For $remote_addr`
(NOT `$proxy_add_x_forwarded_for`) to prevent header spoofing.

**File permissions:**
```bash
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/openclaw.json
chmod 600 ~/.openclaw/.env
chmod 700 ~/.openclaw/credentials
chown -R 1000:1000 ~/.openclaw  # for Docker deployments
```

**Known CVEs/issues:**
- CVE-2026-25253 (CVSS 8.8): Critical RCE patched in v2026.1.29 — always run latest
- Issue #11202: API keys leaked into prompt context via `${ENV_VAR}` substitution
- Tens of thousands of exposed instances found online due to misconfigured `0.0.0.0` binding
  (estimates range from ~21,000 to 135,000+ depending on scan methodology and date)
- Infostealers specifically target `~/.openclaw/` config files

Run `openclaw security audit --deep` after every deployment.

---

## Backup & Migration

OpenClaw's full state lives in **two directories** — both must be backed up:

- `~/.openclaw/` — config, credentials, sessions, channel auth, memory DB
- `~/.openclaw/workspace/` — workspace Markdown files, skills, memory logs

**Official 4-step migration:**
1. `openclaw gateway stop` → `tar -czf openclaw-state.tgz ~/.openclaw`
2. Install OpenClaw on new host
3. `scp`/`rsync` archive → extract → fix ownership (`chown -R openclaw:openclaw`)
4. `openclaw doctor` → `openclaw gateway restart` → `openclaw status`

**Security:** API keys are stored **cleartext** in the state dir (no native
encryption). Always GPG-encrypt backups before offsite storage. Treat backup
archives as production secrets.

**Ansible backup role tasks (official playbook has none — must add):**
1. `systemctl stop openclaw`
2. `tar -czf` timestamped archive of `~/.openclaw/`
3. GPG AES256 encrypt (password from Ansible Vault)
4. Rotate: keep N daily + M weekly archives
5. rclone/rsync to S3, Cloudflare R2, or remote server
6. `sqlite3 memory.db "PRAGMA integrity_check;"` to verify DB
7. `systemctl start openclaw`
8. Schedule via Ansible `cron` module

**Community tools:** `simple-backup` skill (rclone + GPG), `migrate` skill
(portable tarball with `--include-sessions` and `--include-credentials` flags).

---

## Ansible Deployment Checklist

The `openclaw-ansible` official playbook handles: UFW, fail2ban, Docker,
Node.js 22, systemd hardening, Tailscale. It does **not** include: Nginx,
TLS, gateway token management, backup/restore.

Deployment order for a complete setup:
1. Install Node.js 22 + npm
2. `npm install -g openclaw@latest`
3. Create dirs: `~/.openclaw/{workspace/memory,credentials,workspace/skills}` (chmod 700)
4. Template `.env` (chmod 600) with API keys + `OPENCLAW_GATEWAY_TOKEN`
5. Template `openclaw.json` with gateway/model/channel config
6. Template workspace Markdown files (SOUL.md, AGENTS.md, USER.md, etc.)
7. Install systemd unit (`openclaw onboard --install-daemon`)
8. Configure UFW (deny 18789, allow 22/443 from LAN)
9. Optional: Nginx reverse proxy, Docker sandboxing, Tailscale Serve

---

## Common Troubleshooting

**Gateway won't start**
- Check `openclaw doctor` output — validates config schema and services
- Verify Node.js ≥22: `node --version`
- Check systemd: `journalctl -u openclaw -n 50`
- Port conflict: `ss -tlnp | grep 18789`

**WebSocket connections failing through Nginx**
- Missing `proxy_set_header Upgrade $http_upgrade` or `Connection $connection_upgrade`
- Timeout too short — must be 86400s for long-lived WS connections
- Missing `trustedProxies: ["127.0.0.1"]` in openclaw.json
- Wrong `X-Forwarded-For` header setup (use `$remote_addr`, not `$proxy_add_x_forwarded_for`)

**Gateway accessible only from localhost (intended)**
- `bind: "loopback"` is correct — access via SSH tunnel or reverse proxy
- For LAN access: add Nginx on port 443 proxying to 127.0.0.1:18789
- For remote access: use Tailscale Serve (`gateway.tailscale.mode: "serve"`)

**Heartbeat firing at night / excessive API costs**
- Set `heartbeat.activeHours: { start: "07:30", end: "22:00", timezone: "..." }`
- Switch heartbeat model to Haiku (48 runs/day at $0.005 vs $0.24 for Opus)
- Trim HEARTBEAT.md to ≤10 lines; empty file skips API call entirely

**Channel reconnecting after migration**
- WhatsApp: Baileys credentials live in `~/.openclaw/channels/` — must be copied
- Telegram/Discord: token-based, no reconnect needed; just restore `.env`
- Signal: device linking state in channels dir — may need re-pairing

**BOOT.md firing multiple times**
- Known bug #9167 — make all BOOT.md tasks idempotent
- Check `hooks.internal.enabled` is only set once in config

**Config changes not taking effect**
- Hot-reload works for: channels, agents, tools, hooks, cron
- Requires restart for: port, bind, auth mode, TLS settings
- Restart: `systemctl restart openclaw` or `openclaw gateway restart`

**`openclaw doctor` reports schema errors**
- openclaw.json is JSON5 — comments and trailing commas are valid
- Common mistake: invalid model string (use `provider/model-name` format)
- Check `$include` paths are relative to config file location
