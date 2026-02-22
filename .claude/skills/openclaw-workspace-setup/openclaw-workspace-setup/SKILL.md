---
name: openclaw-workspace-setup
description: "Interactive guided setup for configuring an OpenClaw agent's identity and personal context files. Use this skill whenever the user wants to define or update their OpenClaw agent's workspace files — IDENTITY.md, USER.md, SOUL.md, AGENTS.md, HEARTBEAT.md, BOOT.md, or TOOLS.md. Trigger on phrases like \"set up my openclaw agent\", \"configure agent identity\", \"define my USER.md\", \"set up workspace files\", \"openclaw identity\", \"SOUL.md setup\", \"configure my agent personality\", or any mention of personalizing OpenClaw workspace files. Also trigger when the user wants to populate vault_openclaw_identity_md or vault_openclaw_user_md in vault.yml."
---

# OpenClaw Workspace Setup

OpenClaw's eight workspace files form a layered identity system. Together they
tell the agent who it is, who you are, what tools it has, and what to check
proactively. This skill guides you through building those files and placing
them correctly in the Ansible deployment.

For full content guidance on each file, see `references/file-guide.md`.

---

## Architecture: where files live

Two files are bootstrapped via **Ansible vault** on first deploy:
- `IDENTITY.md` → stored in `vault_openclaw_identity_md` in `ansible/group_vars/vault.yml`
- `USER.md` → stored in `vault_openclaw_user_md` in `ansible/group_vars/vault.yml`

Both are deployed with `force: false` — they are written once and never
overwritten by Ansible. After first deploy, the agent maintains them directly.

The remaining files belong in the **private `openclaw-config` repo**:
`SOUL.md`, `AGENTS.md`, `HEARTBEAT.md`, `BOOT.md`, `TOOLS.md`, `MEMORY.md`

Reference files shipped with this project (in `openclaw-install/local-config/workspace/`)
are the starting templates. They are ready to use or adapt.

---

## How to run this skill

There are two paths depending on what the user needs:

### Path A — Full onboarding (new deployment)
The user is setting up a fresh agent and needs to create all workspace files.
Walk through the interview in the order below, then output everything.

### Path B — Targeted update
The user wants to change or review a specific file. Go straight to that
section, ask only the relevant questions, and output just that file.

Ask the user which path they need if it's not clear from context.

---

## Interview guide

Work conversationally, not as a form. The goal is to pull out the information
naturally, then shape it into tightly formatted files. Don't ask all questions
at once — let answers inform follow-ups.

Reference `references/file-guide.md` for what each file should contain,
recommended length, and anti-patterns to avoid.

### 1. User context (→ USER.md)

Minimum needed:
- Name and preferred form of address
- Timezone and location
- Languages (work language vs. local language if different)
- Work role and primary focus
- Communication style preferences
- Any life context the agent should know (family schedule, availability patterns)

Good prompts if the user is sparse:
- "What should the agent call you?"
- "What's your main work — what does a typical workday look like?"
- "Anything the agent should know about your schedule or availability?"
- "Any pet peeves — things an assistant should never do?"

Aim for a file under 40 lines. Personal details that are too sensitive for
a repo go in the private openclaw-config repo only.

### 2. Agent identity (→ IDENTITY.md)

Minimum needed:
- Name (what the agent calls itself)
- Creature / self-concept (AI? system? familiar?)
- Vibe (one-line personality descriptor)
- Signature emoji (used for reactions; default is 🦞)

Good prompts:
- "What should the agent call itself? Something punchy tends to work well."
- "How would you describe its personality in one line — e.g. 'dry-humored sysadmin' or 'direct pragmatic co-pilot'?"

Avatar is optional — skip unless the user raises it.

### 3. Agent personality (→ SOUL.md)

Only needed if the user wants to customize agent behavior beyond defaults.
The reference files in `openclaw-install/local-config/workspace/` are solid
defaults — offer to use them as-is or adapt.

Key sections: Core Truths, Communication Style, Values, Boundaries,
Anti-Patterns, Example Responses, Continuity.

Keep under 100 lines. A few specific rules beat many vague ones.

### 4. Operating contract (→ AGENTS.md)

Covers: session startup protocol, memory protocol, domain priorities, safety
rules, group chat behavior, quality bar.

Usually the defaults in the reference files work well. Ask:
- "What are your agent's main domains? (e.g. business automation, smart home, productivity)"
- "Any workflows explicitly disabled for now?"
- "Any safety rules beyond the defaults?"

### 5. Heartbeat (→ HEARTBEAT.md)

5–10 lines max. Each line runs 48 times a day — keep it minimal.

Ask:
- "What should the agent check every 30 minutes? Examples: email urgency, calendar alerts, service health."
- "What are your quiet hours? (Agent won't send non-urgent messages outside this window.)"
- "Any checks explicitly disabled?"

### 6. Boot ritual (→ BOOT.md)

Runs every gateway restart. Focused on initialization, not monitoring.

Ask:
- "What should the agent do on startup? Examples: read memory, check calendar, send a morning summary."

### 7. Tools and environment (→ TOOLS.md)

Documents local tool conventions and infrastructure specifics. Doesn't define
tool capabilities — just maps the user's specific setup.

Ask about:
- SSH hosts (aliases, users, roles)
- Key infrastructure (Ansible paths, project locations)
- Language/framework conventions
- Any device or service mappings the agent needs

---

## Output format

After the interview, produce each file as a clearly labeled fenced block so
the user can copy it directly.

For files going into `vault.yml`, format the output as YAML-ready multiline
string blocks:

```yaml
vault_openclaw_identity_md: |
  # IDENTITY.md
  ... content ...

vault_openclaw_user_md: |
  # USER.md
  ... content ...
```

Then remind the user:
1. Paste those entries into `ansible/group_vars/vault.yml`
2. Encrypt with `ansible-vault encrypt ansible/group_vars/vault.yml`
3. For SOUL.md, AGENTS.md, HEARTBEAT.md, BOOT.md, TOOLS.md: place in the
   private `openclaw-config` repo
4. Run `ansible/` deploy with `make deploy TAGS=openclaw` to push config

---

## Quality checks before finishing

Before presenting output, review each file against these:

- **USER.md**: No secrets, tokens, or private endpoints. Under 40 lines.
  Personal/sensitive details only in private repo version.
- **IDENTITY.md**: Name is present. Emoji is a single character. Vibe is one
  clear line. Under 25 lines.
- **SOUL.md**: No contradictory instructions (e.g. "be brief" + "always explain
  in detail"). No vague directives. Under 100 lines.
- **AGENTS.md**: Session startup protocol is explicit. Safety rules are present.
  Domain priorities are concrete, not generic. Under 80 lines.
- **HEARTBEAT.md**: Under 15 lines total. Active hours set. At least one quiet-
  hours rule defined.
- **BOOT.md**: No monitoring tasks (those go in HEARTBEAT.md). Output contract
  is defined (when to send NO_REPLY).
- **TOOLS.md**: No raw secrets. Paths are placeholders or explicitly noted as
  user-specific. Under 60 lines.

If a file looks bloated or contradictory, flag it and suggest trimming before
outputting.
