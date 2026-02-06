# OpenClaw skills, configuration, and hard-won lessons from the field

**OpenClaw is the fastest-growing open-source AI agent platform in history, but the gap between its viral demos and real-world production use is significant.** With **145,000+ GitHub stars**, a **3,000+ skill registry**, and a **60,000-member Discord**, it has ignited massive enthusiasm for personal AI agents — yet experienced deployers consistently warn that security vulnerabilities, runaway API costs ($300–750/month for heavy users), and configuration fragility make it far from plug-and-play. This report synthesizes community data, install counts, security research, and practitioner accounts to identify what actually works, what doesn't, and how to deploy OpenClaw responsibly.

Originally created by Peter Steinberger (founder of PSPDFKit) under the name "Clawdbot" in November 2025, the project underwent two rapid rebrands — to Moltbot, then OpenClaw — before exploding in popularity in late January 2026. It runs locally on your hardware, connects to LLMs (Claude, GPT, Gemini, DeepSeek), and surfaces through messaging platforms like WhatsApp, Telegram, Discord, and Slack. Its extension system — skills stored as Markdown SKILL.md files — has spawned a massive ecosystem, but also a significant attack surface.

---

## The skills people actually install and use

Verified install data from ClawHub reveals a stark concentration at the top. **Vercel's `vercel-react-best-practices` dominates with 22,475 installs**, followed by `web-design-guidelines` at 17,135. After that, numbers drop dramatically — Expo's `upgrading-expo` has 1,192 installs, and Steinberger's own `frontend-design` sits at 566. The long tail is extremely long: most of the 3,000+ skills have minimal adoption.

The VoltAgent curated list (9,200 GitHub stars) catalogs **1,715 vetted skills across 31 categories**. Community recommendations, blog posts, and trending data converge on several consistently popular skills by use case:

**For developers**, the essential stack centers on `coding-agent` (runs Codex CLI, Claude Code, or Pi Coding Agent as background processes), `github` (full GitHub CLI integration for PRs, issues, and CI), `conventional-commits`, and `deepwiki` (queries auto-generated documentation for any GitHub repo). The `agent-browser` skill — a Rust-based headless browser automation tool — is trending heavily for web scraping and testing workflows.

**For productivity**, `google-calendar` is consistently described as the "most immediately useful" skill. `clawlist` is called a must-use for any multi-step project. The `cron-creator` skill (natural language to cron jobs) appears in nearly every recommendation list. Apple ecosystem users gravitate toward `apple-notes`, `apple-reminders`, and `things` (Things 3 task manager).

**For smart home automation**, `home-assistant` is the clear leader, enabling full control of Home Assistant installations. `philips-hue` for lighting and `camera-capture` for RTSP/ONVIF cameras round out the most-recommended IoT stack.

**For DevOps**, the category is the largest (144 skills), with `dokploy`, `cloudflare/wrangler`, `hetzner-cloud`, `coolify`, and `proxmox` leading adoption. Nathan Broadbent's detailed deployment write-up showed his agent managing Kubernetes, Terraform, and Ansible autonomously — but this represents an extreme power-user case.

---

## Skill combinations that work together in practice

Community guides and power-user reports converge on five proven skill stacks. The **Developer Stack** pairs `coding-agent` + `github` + `conventional-commits` + `deepwiki` + `agent-browser`, giving the agent the ability to write code, manage repositories, browse documentation, and automate web testing. The **Productivity Stack** combines `google-calendar` + `himalaya` (email via IMAP/SMTP) + a task manager (`things` or `clawlist`) + `obsidian-vault` or `apple-notes` for knowledge management. The **DevOps Stack** links `dokploy` or `coolify` with cloud provider skills (`hetzner`, `digital-ocean`, `cloudflare`) and `proxmox` for infrastructure management. The **Smart Home Stack** runs `home-assistant` + `philips-hue` + `cron-creator` for scheduled automations. The **Content Creator Stack** uses `remotion-best-practices` + `veo` (Google video generation) + `frontend-design` + `slack` for production workflows.

A critical pattern among successful deployments: **start with 3–5 skills maximum**, get them working reliably, then expand incrementally. Nathan Broadbent's sophisticated 15-cron-job, 24-custom-script deployment evolved over weeks — it was not configured all at once. Users who install dozens of skills immediately report instability and confusion.

---

## Configuration architecture and best practices for production

OpenClaw's configuration lives at `~/.openclaw/openclaw.json` in JSON5 format (supports comments and trailing commas). The gateway validates strictly — **unknown keys, malformed types, or invalid values prevent startup entirely**, which is both a safety feature and a source of frustration. One experienced user reported their service crashed 27 times: one was a bug, and 26 were from editing the config file.

The most critical configuration practice is **version-controlling your configuration**. Initialize a Git repo for `~/.openclaw/` and commit before every change. The community calls Git "your undo button" for OpenClaw config. The `$include` directive lets you split configuration across multiple files, which is essential for multi-agent setups.

**Workspace organization** follows a file-and-folder convention. Key files injected into the system prompt include `SOUL.md` (agent personality and rules), `MEMORY.md` (long-term patterns), `HEARTBEAT.md` (current priorities for proactive behavior), `AGENTS.md`, `TOOLS.md`, and `USER.md`. These files are editable as plain Markdown and searchable with tools like Raycast or integratable with Obsidian. Per-agent workspaces (`~/.openclaw/workspace-<agentId>`) provide isolation between different agents.

For **model configuration**, experienced users strongly recommend failover chains rather than a single model: set Claude Sonnet as primary, Haiku as fallback for simple tasks, and Opus only for complex reasoning. This pattern alone can cut costs by **50–80%**. The OpenRouter Auto Model (`openrouter/openrouter/auto`) is another option that automatically routes to cost-effective models per prompt. Local models via LM Studio or Ollama provide zero-cost fallback for basic tasks, though they require minimum **64K context windows** to function adequately.

---

## DM policies, sandbox settings, and channel routing done right

OpenClaw's security model operates on three layers: **identity first** (who can talk to the bot), **scope next** (where the bot can act), and **model last** (assume the model can be manipulated).

**DM policies** control inbound access and offer four modes. `pairing` (the default and recommended setting) requires unknown senders to enter a short code approved via CLI. `allowlist` restricts to explicitly listed contacts. `open` lets anyone interact — the documentation warns to use this with "extreme caution." `disabled` turns off DMs entirely. These are configured per-channel:

```json
{
  "channels": {
    "telegram": { "dmPolicy": "pairing" },
    "discord": { "dm": { "policy": "allowlist" } }
  }
}
```

**Sandbox settings** control execution isolation through `agents.defaults.sandbox.mode`. The `"off"` setting provides no sandbox (suitable only for trusted personal use). `"non-main"` sandboxes group and channel sessions in Docker while keeping the main session unsandboxed. `"all"` sandboxes everything. The sandbox scope can be per-agent (one container) or per-session. Critically, sandboxed environments **do not inherit host environment variables** — a common source of skill failures that requires explicit configuration via `agents.defaults.sandbox.docker.env`.

**Channel routing** in multi-agent setups uses bindings that match inbound messages to specific agents. Peer-level bindings (matching specific phone numbers or user IDs) always override channel-wide rules. Group messages support mention gating (`requireMention: true`), which prevents the bot from responding to every message in a group — a setting the security community considers mandatory to prevent prompt injection via group participants.

---

## Security realities that the demos don't show

Security is OpenClaw's most consequential challenge. **Zenity Labs demonstrated in February 2026 that a hidden prompt in an innocent document can hijack OpenClaw entirely**, creating a Telegram backdoor and establishing persistence by modifying `SOUL.md` via a cron job. ZeroLeaks scored OpenClaw **2 out of 100** on security, with an 84% data extraction rate. Security researchers found **923+ OpenClaw gateways completely exposed on the public internet** with no authentication.

The skill ecosystem is an active attack surface. Cisco's AI Threat Research team found that **26% of 31,000 agent skills analyzed contained at least one vulnerability**. Koi Security audited all 2,857 ClawHub skills and found **341 malicious ones** — 335 from a single campaign called "ClawHavoc" that masqueraded as popular tools to exfiltrate cryptocurrency credentials. A malicious skill was even artificially inflated to rank #1 in the registry.

The essential security checklist from community consensus:

- Never expose gateway port 18789 to the public internet — use **Tailscale Serve** for remote access
- Keep DM policy at `pairing` and set `requireMention: true` in all groups
- Set file permissions: `chmod 700 ~/.openclaw`, config file `chmod 600`
- Run `openclaw security audit --deep` regularly and `openclaw doctor` after every config change
- Install security-focused skills like `clawdex` (scans against known malicious skill database) and `sona-security-audit` before adding third-party skills
- Deploy on **isolated infrastructure** (dedicated VPS, VM, or container) — never on a machine with sensitive personal data
- Start deny-by-default for tools, add capabilities incrementally with explicit scopes
- Use short-lived credentials and distinct identities per tool integration
- Run `OPENCLAW_SHOW_SECRETS=0` when sharing any debug output

---

## The cost trap and how to avoid it

API token costs are the most common source of user frustration. Without optimization, active users report spending **$300–750 per month**. The German tech magazine c't burned over **$100 in a single day** of testing. Tech blogger Federico Viticci reportedly consumed **1.8 million tokens in one month ($3,600)**. Even installation and initial configuration can cost **$250+ in API calls** as the agent debugs OAuth tokens and troubleshoots integrations.

Three mechanisms drive costs: **context accumulation** (every message sends the full conversation history — sessions can occupy 56–58% of a 400K context window), **heartbeat and cron jobs** (one user's 5-minute email check cost $50/day; another's 30-minute heartbeat spent $18.75 overnight just asking "Is it daytime yet?"), and **runaway automation loops** ($200 in a single day is not uncommon).

The optimization playbook from experienced users:

- **Reset sessions regularly** with `/new` to clear accumulated context
- **Monitor obsessively** using `/status`, `/usage full`, and `/context list` from day one
- **Configure model failover chains**: Sonnet → Haiku → local model (cuts costs 50–80%)
- **Set heartbeat intervals just under cache TTL** (e.g., 55 minutes for a 1-hour TTL) to exploit prompt caching
- **Reduce `bootstrapMaxChars`** to limit workspace file injection into the system prompt
- **Set hard spending caps at the provider level** (Anthropic Console, OpenAI billing) before any experimentation
- **Budget $50–100/month** for a realistic learning period; treat the first month as tuition

With disciplined optimization and multi-model routing, community reports suggest costs can be brought down to approximately **$70/month** for moderate usage.

---

## The pitfalls that catch everyone

**Configuration fragility** is the most universally reported operational issue. The strict JSON5 parser gives vague "Parse Error" messages with no helpful diagnostics. Mixing Gemini 3 and Gemini 2.5 on Vertex AI causes total system failure with no error message — the system simply freezes. Mixing vendors (Claude + Gemini) is paradoxically more stable than mixing versions from the same vendor.

**Node.js version requirements** (v22+) cause the most installation failures. Version managers like nvm, fnm, and volta create additional problems because the daemon service doesn't load shell initialization files — `openclaw doctor` can diagnose and fix this. Bun is entirely unsupported for WhatsApp and Telegram channels.

**iMessage integration** has a critical undocumented requirement: if OpenClaw uses your personal iCloud account, it reads its own replies as new messages, creating an infinite loop. The fix requires creating a **dedicated "Agent Apple ID"** — your personal account receives messages, the agent account sends them.

**Random gateway freezes** are common enough that experienced users build watchdog scripts: ping every 5 minutes, escalating retries, then kill and restart the gateway if unresponsive. As one user put it, "True automation includes automated rescue."

The most common beginner mistakes: skipping the onboarding wizard, not running `openclaw doctor`, failing to set spending limits before experimenting, granting full permissions immediately, installing untrusted skills without vetting, and running integrations on personal accounts rather than dedicated ones. The community's consistent advice: "OpenClaw is a modified race car. It is fast, but you need to know how to change the oil."

---

## Conclusion

OpenClaw represents a genuine paradigm shift from "AI that talks" to "AI that acts," and its skill ecosystem is impressively broad. But the project's current state rewards careful, security-conscious operators and punishes casual experimentation. **The most successful deployments share three traits**: they start with a minimal skill set (3–5 skills) and expand incrementally, they run on isolated infrastructure with strict DM policies and sandboxing, and they implement aggressive cost controls from day one with model failover chains and session management.

The security situation remains the elephant in the room — with a **2/100 security score** from independent researchers and hundreds of malicious skills in the registry, treating OpenClaw as anything other than experimental infrastructure running untrusted code on an isolated machine would be premature. The project is evolving rapidly (the community has already matured from pure hype to practical troubleshooting), but the documentation's own admission — "There is no 'perfectly secure' setup" — should be taken literally. For those willing to invest the time, budget, and operational discipline, the payoff is a genuinely useful autonomous agent. For everyone else, watching from a safe distance while the ecosystem matures remains the prudent choice.
