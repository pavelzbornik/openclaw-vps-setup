#Requires -Version 5.1
<#
.SYNOPSIS
    Creates missing 1Password items and regenerates group_vars/vault.yml.

.DESCRIPTION
    Run once before the first deploy, and any time you update values in 1Password.

    What it does:
      1. Creates the OpenClaw vault (if absent)
      2. Creates any missing items with placeholders — existing items are untouched
      3. Reads all config items from 1Password and writes group_vars/vault.yml

    Secrets (API keys, Tailscale key) stay in 1Password and are injected at deploy
    time via op inject. vault.yml only holds non-secret config (Discord IDs,
    agent identity text).

    Requires OP_SERVICE_ACCOUNT_TOKEN to be set in your shell.

.PARAMETER Vault
    Name of the 1Password vault. Default: OpenClaw

.EXAMPLE
    $env:OP_SERVICE_ACCOUNT_TOKEN = "ops_..."
    .\scripts\bootstrap-1password.ps1
#>
[CmdletBinding()]
param(
    [string]$Vault = "OpenClaw",
    [string]$DockerImage = "python:3.11-bookworm"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $env:OP_SERVICE_ACCOUNT_TOKEN) {
    throw "OP_SERVICE_ACCOUNT_TOKEN is not set. Set it in your shell and re-run:`n  `$env:OP_SERVICE_ACCOUNT_TOKEN = 'ops_...'"
}

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ansibleDir = (Resolve-Path (Join-Path $scriptDir "..")).Path
$repoDir    = (Resolve-Path (Join-Path $ansibleDir "..")).Path
$repoMount  = $repoDir.Replace("\", "/")

# ── Python bootstrap script (runs inside Docker) ───────────────────────────────
$pythonScript = @"
import os, subprocess, sys, secrets

VAULT = os.environ.get('VAULT', 'OpenClaw')
PLACEHOLDERS = ('PLACEHOLDER_', 'REPLACE_ME', '<!--')

def sh(*cmd, fatal=False):
    r = subprocess.run(list(cmd), capture_output=True, text=True)
    if r.returncode != 0 and fatal:
        cmd_str = ' '.join(cmd)
        print(f'[ERROR] Command failed: {cmd_str}', file=sys.stderr)
        print(r.stderr.strip(), file=sys.stderr)
        sys.exit(r.returncode)
    return r

def op(*args, fatal=False):
    return sh('op', *args, fatal=fatal)

def item_exists(title):
    return op('item', 'get', title, '--vault', VAULT).returncode == 0

def create_item(title, category='Login', **fields):
    if item_exists(title):
        print(f'  [ok]     {title}')
        return True
    print(f'  [create] {title}')
    fargs = []
    for k, v in fields.items():
        ftype = 'text' if k in ('allowlist', 'guilds', 'content') else 'password'
        fargs.append(f'{k}[{ftype}]={v}')
    r = op('item', 'create', '--vault', VAULT, '--title', title, '--category', category, *fargs)
    if r.returncode != 0:
        print(f'  [ERROR]  Failed to create {title}: {r.stderr.strip()}', file=sys.stderr)
        return False
    return True

def get_field(title, field):
    r = op('item', 'get', title, '--vault', VAULT, '--fields', field)
    if r.returncode != 0:
        print(f'  [warn] Could not read {title}/{field}: {r.stderr.strip()}')
        return ''
    return r.stdout.strip()

def is_placeholder(value):
    return not value or any(p in value for p in PLACEHOLDERS)

# ── Install 1Password CLI ──────────────────────────────────────────────────────
print('[*] Installing 1Password CLI...')
sh('curl', '-sLo', '/tmp/op.deb',
   'https://downloads.1password.com/linux/debian/amd64/stable/1password-cli-amd64-latest.deb',
   fatal=True)
sh('dpkg', '-i', '/tmp/op.deb', fatal=True)
version = op('--version', fatal=True).stdout.strip()
print(f'    op CLI {version}')

# ── Ensure vault exists ────────────────────────────────────────────────────────
r = op('vault', 'get', VAULT)
if r.returncode != 0:
    print(f'[*] Creating vault: {VAULT}')
    op('vault', 'create', VAULT, fatal=True)
else:
    print(f'[*] Vault "{VAULT}" found')

# ── Secret items (values injected into .env via op inject at deploy time) ──────
print('')
print('[*] Secret items (op://OpenClaw/<name>/credential):')
create_item('Telegram Bot',               credential='PLACEHOLDER_TELEGRAM_BOT_TOKEN')
create_item('discord',                    credential='PLACEHOLDER_DISCORD_BOT_TOKEN')
create_item('OpenAI',                     credential='PLACEHOLDER_OPENAI_API_KEY')
create_item('OpenRouter API Credentials', credential='PLACEHOLDER_OPENROUTER_API_KEY')
create_item('Tailscale',                  credential='PLACEHOLDER_TAILSCALE_AUTHKEY')

if not item_exists('OpenClaw Gateway'):
    print('  [create] OpenClaw Gateway (auto-generating token)')
    r = op('item', 'create', '--vault', VAULT, '--title', 'OpenClaw Gateway',
           '--category', 'Login', f'credential[password]={secrets.token_urlsafe(32)}')
    if r.returncode != 0:
        print(f'  [ERROR] {r.stderr.strip()}', file=sys.stderr)
else:
    print('  [ok]     OpenClaw Gateway')

# ── Config items (read back into vault.yml) ────────────────────────────────────
print('')
print('[*] Config items (values written to group_vars/vault.yml):')
# Discord allowlist/guilds are added to the existing discord item (already created above)
op('item', 'edit', 'discord', '--vault', VAULT,
   'allowlist=REPLACE_ME_USER_ID', 'guilds=REPLACE_ME_GUILD_ID')
create_item('OpenClaw',
    identity_md='# IDENTITY.md\n<!-- Replace with your agent identity content -->',
    user_md='# USER.md\n<!-- Replace with your user context content -->')

# ── Read config values and generate vault.yml ──────────────────────────────────
print('')
print('[*] Reading config values from 1Password...')

allowlist = get_field('discord', 'allowlist')
guilds    = get_field('discord', 'guilds')
identity  = get_field('OpenClaw', 'identity_md')
user_md   = get_field('OpenClaw', 'user_md')

allowlist_display = '(placeholder)' if is_placeholder(allowlist) else allowlist
guilds_display = '(placeholder)' if is_placeholder(guilds) else guilds
identity_display = '(placeholder)' if is_placeholder(identity) else '(set, ' + str(len(identity)) + ' chars)'
user_md_display = '(placeholder)' if is_placeholder(user_md) else '(set, ' + str(len(user_md)) + ' chars)'
print(f'    discord allowlist : {allowlist_display}')
print(f'    discord guilds    : {guilds_display}')
print(f'    IDENTITY.md       : {identity_display}')
print(f'    USER.md           : {user_md_display}')

def yaml_list(raw):
    if is_placeholder(raw):
        return '[]'
    items = [v.strip() for v in raw.split(',') if v.strip()]
    return ('\n' + '\n'.join(f'  - "{item}"' for item in items)) if items else '[]'

def yaml_block(raw):
    if is_placeholder(raw):
        return '""'
    return '|\n' + '\n'.join(f'  {line}' for line in raw.splitlines())

vault_yml = '\n'.join([
    '---',
    '# Generated by bootstrap-1password.ps1 — edit values in 1Password then re-run.',
    '',
    f'vault_openclaw_discord_allowlist: {yaml_list(allowlist)}',
    '',
    f'vault_openclaw_discord_guilds: {yaml_list(guilds)}',
    '',
    f'vault_openclaw_identity_md: {yaml_block(identity)}',
    '',
    f'vault_openclaw_user_md: {yaml_block(user_md)}',
    '',
])

vault_path = '/work/ansible/group_vars/vault.yml'
with open(vault_path, 'w') as f:
    f.write(vault_yml)

print('')
print(f'[+] vault.yml written to {vault_path}')
print('')

needs_update = [
    name for name, val in [
        ('Telegram Bot',               get_field('Telegram Bot',               'credential')),
        ('discord',                    get_field('discord',                    'credential')),
        ('OpenAI',                     get_field('OpenAI',                     'credential')),
        ('OpenRouter API Credentials', get_field('OpenRouter API Credentials', 'credential')),
        ('Tailscale',                  get_field('Tailscale',                  'credential')),
        ('discord/allowlist',      allowlist),
        ('discord/guilds',         guilds),
        ('OpenClaw/identity_md',   identity),
        ('OpenClaw/user_md',       user_md),
    ]
    if is_placeholder(val)
]

if needs_update:
    print('[!] Update these items in 1Password, then re-run bootstrap-1password.ps1:')
    for name in needs_update:
        print(f'    - {name}')
else:
    print('[+] All items have real values — ready to deploy.')
"@

Write-Host "[INFO] Bootstrapping 1Password vault '$Vault' via Docker..." -ForegroundColor Green

& docker run --rm `
    -e "OP_SERVICE_ACCOUNT_TOKEN=$($env:OP_SERVICE_ACCOUNT_TOKEN)" `
    -e "VAULT=$Vault" `
    -v "${repoMount}:/work" `
    $DockerImage `
    python3 -c $pythonScript

if ($LASTEXITCODE -ne 0) {
    throw "Bootstrap failed with Docker exit code $LASTEXITCODE."
}
