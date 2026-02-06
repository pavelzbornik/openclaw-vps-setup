# OpenClaw Config Repo (Git Sync)

This repo includes the `openclaw_git` role to sync a separate configuration repository to the VM.

## What It Does

- Clones your config repo to `~/openclaw-config` on the VM
- Creates a safe `.gitignore` if missing
- Optionally migrates `workspace/` content into `~/.openclaw/workspace`
- Writes an `openclaw.json.template` for initial setup

## Configure It

Edit [ansible/group_vars/all.yml](../ansible/group_vars/all.yml):

- `openclaw_git_sync_enabled`: enable or disable syncing
- `openclaw_config_repo`: URL to your config repo
- `openclaw_config_repo_dest`: destination on the VM

If the config repo contains a `workspace/` directory, the role enables migration mode and copies workspace files to `~/.openclaw/workspace`.

## Recommended Repo Structure

```
openclaw-config/
├── openclaw.json.template
├── workspace/
│   ├── AGENTS.md
│   ├── SOUL.md
│   ├── TOOLS.md
│   ├── IDENTITY.md
│   ├── USER.md
│   └── skills/
└── skills/
```

## Secrets and Safety

Do not commit real secrets. The role writes a `.gitignore` that excludes:

- `credentials/`, `sessions/`, `logs/`
- `openclaw.json`, `.env`, token files, and `MEMORY.md`

## GitHub Token (Optional)

If you store a GitHub token in 1Password, the role can authenticate `gh` to clone private repos.
Set:

- `OP_SERVICE_ACCOUNT_TOKEN` in your environment
- Vault/item/field names in `group_vars/all.yml`
