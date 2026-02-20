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
- `openclaw_workspace_source`: set to `private_repo` (default)
- `openclaw_workspace_repo_path`: workspace path inside private repo
- `openclaw_workspace_personal_files`: list of personal markdown files deployed to `~/.openclaw/workspace`
- `openclaw_git_cron_enabled`: enable scheduled commit/push via cron
- `openclaw_git_cron_minute` / `openclaw_git_cron_hour`: schedule for regular sync

If the config repo contains a `workspace/` directory, the role enables migration mode and copies workspace files to `~/.openclaw/workspace`.

When `openclaw_workspace_source: private_repo`, personal workspace files are deployed from the private repo on every Ansible run.

## Regular Automatic Commits

The playbook installs a cron job for regular OpenClaw config sync commits/pushes:

- Runs as `{{ openclaw_user }}` on the configured schedule.
- Executes `~/sync-openclaw-config.sh` with `flock` lock protection.
- Writes output to `~/sync-openclaw-config.log`.

When cron scheduling is enabled, the legacy `openclaw-backup.timer` is disabled to avoid duplicate runs.

## Temporary Local Staging (Public Repo)

For temporary editing in this public repository, use:

- `docs/research/local-config/workspace/`

That folder is gitignored by the root `.gitignore` (`docs/research/`).
After editing, move/copy those files into your private `openclaw-config` repo under `workspace/`.

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
