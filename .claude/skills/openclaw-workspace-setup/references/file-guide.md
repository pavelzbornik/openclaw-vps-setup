# OpenClaw Workspace File Guide

Quick reference for what each file does, what goes in it, and common mistakes.

---

## Table of Contents
1. [IDENTITY.md](#identitymd)
2. [USER.md](#usermd)
3. [SOUL.md](#soulmd)
4. [AGENTS.md](#agentsmd)
5. [HEARTBEAT.md](#heartbeatmd)
6. [BOOT.md](#bootmd)
7. [TOOLS.md](#toolsmd)
8. [MEMORY.md](#memorymd)

---

## IDENTITY.md

**Purpose**: Agent's runtime identity — name, personality shorthand, emoji.
**Loaded**: Every session. Applied via `openclaw agents set-identity --from-identity`.
**Target length**: 15–25 lines.
**Lives in**: `vault_openclaw_identity_md` in `vault.yml` (bootstrapped on first deploy).

### Required fields
- **Name**: Short, distinctive. Real names, themed names, or short punchy handles all work.
- **Creature**: AI? Robot? Familiar? Ghost? Shapes self-perception in conversations.
- **Vibe**: One-line personality descriptor. E.g., "dry-humored sysadmin" or "sharp and efficient".
- **Emoji**: Signature reaction emoji. One character. Default OpenClaw emoji is 🦞.

### Optional fields
- **Avatar**: Workspace-relative path, HTTP URL, or data URI. Skip unless needed.
- **Public Presence Rules**: Behavior in group contexts.
- **Voice Profile**: More detailed tone guidance (optional if covered in SOUL.md).

### Anti-patterns
- Multiple emojis as the signature (use one)
- Long vibe descriptions (keep to one line)
- Putting personality rules here that belong in SOUL.md

### Example structure
```markdown
# IDENTITY.md

## Runtime Identity
- Name: Rex
- Creature: AI assistant
- Vibe: calm, precise, mildly sarcastic
- Emoji: 🔧

## Public Presence Rules
- In group contexts, be concise and high-signal.
- Do not speak for the user without explicit confirmation.
- Prefer "status + next action" formatting over long prose.
```

---

## USER.md

**Purpose**: Who the user is — personalization layer for every session.
**Loaded**: Every session.
**Target length**: 30–40 lines.
**Lives in**: `vault_openclaw_user_md` in `vault.yml` (bootstrapped on first deploy).

### What to include
- Name and preferred form of address
- Timezone and location
- Language preferences (work vs. local if different)
- Work role and current focus
- Communication preferences (tone, format, feedback style)
- Life context affecting availability (schedule patterns, interruption tolerance)
- Assistant behavior hints (technical literacy level, decision style)
- Update policy (does the agent maintain this file proactively?)

### What NOT to include
- Secrets, passwords, API tokens
- Deeply personal or sensitive details (put those in the private repo only)
- Tool-specific details (those go in TOOLS.md)
- Agent behavior rules (those go in AGENTS.md or SOUL.md)

### Anti-patterns
- Overloading with technical preferences that belong in TOOLS.md
- Storing secrets or private endpoints here
- Being so vague it provides no useful context ("I like efficiency")

### Example structure
```markdown
# USER.md

## Identity
- Name: Alex
- Preferred address: Alex (no formalities)
- Timezone: America/New_York
- Location: [City, Country]
- Languages: English

## Communication Preferences
- Tone: direct, concise, practical
- Format: short bullets, clear action items, minimal narrative
- Low tolerance for: verbosity, obvious questions, corporate-speak

## Work Context
- Role: [role — e.g. software engineer, consultant, researcher]
- Focus: [primary work focus]
- Work pattern: [e.g. deep focus blocks, fast context switching]

## Life Context (Operational)
- [Any schedule constraints or availability patterns the agent should know]

## Assistant Behavior Hints
- Assume technical literacy; skip basics unless asked.
- Lead with executable steps and expected outcomes.

## Update Policy
- Keep this file current as stable preferences become clear.
- Do not store secrets here.
```

---

## SOUL.md

**Purpose**: Behavioral core — who the agent is and how it behaves.
**Loaded**: Every session (injected into system prompt).
**Target length**: 50–100 lines hard limit.
**Lives in**: Private `openclaw-config` repo.

### Required sections
- **Core Truths**: 5–7 opinionated behavioral statements. Be specific.
- **Communication Style**: Voice, tone, format preferences.
- **Values**: What the agent prioritizes when there's a trade-off.
- **Boundaries**: What it won't do without asking.
- **Continuity**: Acknowledge stateless sessions; files are the memory substrate.

### Recommended optional sections
- **Anti-Patterns**: Explicitly name behaviors to avoid (great for anti-fluff).
- **Example Responses**: 2–3 good/bad examples calibrate tone better than rules.

### Anti-patterns
- Contradictory instructions ("be brief" AND "always explain thoroughly")
- Vague directives ("be helpful", "be professional")
- Files over 150 lines (every word costs tokens on every session)
- Rules that belong in AGENTS.md (operational protocol) not SOUL.md (character)

### Separator: SOUL.md vs AGENTS.md
- SOUL.md = character, values, tone, what kind of entity the agent is
- AGENTS.md = operational rules, session startup protocol, domain priorities

---

## AGENTS.md

**Purpose**: Operating contract — how sessions work, memory protocol, safety rules.
**Loaded**: Every session.
**Target length**: 60–80 lines.
**Lives in**: Private `openclaw-config` repo.

### Required sections
- **Session Startup Protocol**: Ordered list of what the agent reads/does at start.
  Standard sequence: SOUL.md → USER.md → TOOLS.md → memory files → execute.
- **Memory Protocol**: Where short-lived vs. durable context goes.
  - Short-lived: `memory/YYYY-MM-DD.md` daily notes
  - Durable: `MEMORY.md` (preferences, stable workflows, recurring constraints)
- **Domain Priorities**: The agent's main operating domains, ordered by priority.
- **Safety Rules**: What requires explicit user approval before acting.

### Optional sections
- **Working Style**: Confirm-then-execute vs. ask-first patterns.
- **Group Chat Behavior**: When to respond, when to stay silent.
- **Explicit Scope Exclusions**: Workflows disabled for now (makes opt-in explicit).
- **Quality Bar**: Non-negotiables for output quality.

### Anti-patterns
- Mixing personal preferences here (those belong in USER.md)
- Safety rules so broad they block routine tasks
- Missing domain priorities (without them, the agent treats everything equally)

---

## HEARTBEAT.md

**Purpose**: Periodic monitoring checklist — runs every 30 minutes.
**Contract**: If nothing needs attention, agent replies `HEARTBEAT_OK` (silently dropped).
**Target length**: 5–15 lines total.
**Lives in**: Private `openclaw-config` repo.

### Critical design principle
An empty HEARTBEAT.md skips the API call entirely. Large checklists burn tokens
48+ times per day. Keep it minimal. Each item should be worth checking
continuously.

### Required elements
- Checklist items (5–10 max)
- Quiet hours definition (when NOT to send non-urgent messages)
- Messaging policy (what warrants an alert vs. silence)

### Cost guidance
At 48 runs/day, model selection matters significantly. Configure heartbeat to
use a lightweight model (e.g., Haiku) for cost efficiency.

### Anti-patterns
- More than 10 checklist items
- No quiet hours defined
- Monitoring tasks that should be one-time (put those in BOOT.md)
- Checks that are never actionable (if you can't act on it, remove it)

### Example structure
```markdown
# HEARTBEAT.md

Heartbeat policy: be quiet by default.
If no actionable item exists, return `HEARTBEAT_OK`.

## Checklist
- System health: any failing services on tracked hosts?
- Task continuity: anything in today's memory marked blocked/overdue?
- Project risk: any deployment item requiring quick intervention?

## Current Exclusions
- No email checks.
- No calendar checks.

## Messaging Policy
- Send alerts only for actionable, time-sensitive, high-impact issues.
- Outside quiet hours only: 08:00–22:00 [your timezone].
- During quiet hours, message only for urgent safety/availability incidents.
```

---

## BOOT.md

**Purpose**: Startup ritual — runs every gateway restart.
**Requires**: `hooks.internal.enabled: true` in openclaw.json + `openclaw hooks enable boot-md`.
**Target length**: 10–20 lines.
**Lives in**: Private `openclaw-config` repo.

### Key distinction from HEARTBEAT.md
- BOOT.md = initialization tasks (read memory, pull today's context, send morning summary)
- HEARTBEAT.md = ongoing periodic monitoring

### Required elements
- Ordered startup steps
- Output contract (when to send NO_REPLY vs. a summary)

### Anti-patterns
- Monitoring tasks (those belong in HEARTBEAT.md)
- Non-idempotent tasks (boot may fire multiple times during startup)
- Missing NO_REPLY contract (agent may flood the user with messages)

### Example structure
```markdown
# BOOT.md

## Startup Ritual
1. Read SOUL.md, AGENTS.md, USER.md, TOOLS.md.
2. Read today's + yesterday's memory entries.
3. Load MEMORY.md and identify top recurring constraints.
4. Check core host/service health relevant to active projects.
5. Build a short "today focus" list with max 3 priorities.

## Output Contract
- If no user-visible update is necessary, do not send a long startup message.
- If status is useful, send one concise summary (3–5 bullets).
- If any tool sent a message externally, return NO_REPLY.
```

---

## TOOLS.md

**Purpose**: Environment-specific cheat sheet — local tool conventions and mappings.
**Important**: This file documents the user's specific setup; it does not define
tool capabilities. Skills define how tools work; TOOLS.md maps the user's specifics.
**Target length**: 40–60 lines.
**Lives in**: Private `openclaw-config` repo.

### What to document
- SSH host aliases and connection details
- Infrastructure paths (Ansible playbook locations, inventory paths)
- Project locations and virtual environment conventions
- Test runners, linters, deployment methods
- Device nicknames / room names (for smart home setups)
- General shell/package manager conventions
- Git workflow conventions

### What NOT to include
- Raw API keys, passwords, or tokens (never)
- Tool capability definitions (those go in Skills)
- Policy essays (keep it practical: concrete mappings)

### Example structure
```markdown
# TOOLS.md

## SSH Hosts
- `home-server` → user `localuser`, LAN host
- `vps-prod` → user `deploy`, public VPS

## Ansible
- Playbooks: `~/infra/ansible/`
- Always dry-run first for production hosts: `--check`

## Project Conventions
- Python: pytest, ruff/black, uv for venv management
- Git: small focused commits, feature branches, PR before merge
```

---

## MEMORY.md

**Purpose**: Durable long-term memory — facts and preferences that persist across sessions.
**Loaded**: Only in main DM sessions (not group chats, for security).
**Lives in**: `~/.openclaw/workspace/` (maintained by the agent, not Ansible).

The agent maintains MEMORY.md itself. Ansible does not deploy or manage this file.
Point the agent to this file in AGENTS.md as the durable memory target.
