# Discord Server Provisioning (Terraform)

## Why Discord?

OpenClaw is a conversational AI agent. It needs a channel where operators can send
commands, read responses, and review activity logs. Discord was chosen as the primary
interface for several reasons:

- **Bot API maturity** — Discord's bot API supports slash commands, message history,
  embeds, and channel-level permissions, giving OpenClaw a rich command surface without
  building a custom UI.
- **Multi-device access** — operators can interact with OpenClaw from a desktop, mobile
  device, or web browser without installing anything extra.
- **Access control** — Discord's role and allowlist model maps cleanly to OpenClaw's
  own `allowlist` config (comma-separated Discord user IDs stored in 1Password).
- **Auditability** — Discord's message history is a lightweight audit log of every
  command issued and every response returned.

## Why Terraform?

The Discord server layout (channels, categories, permissions) is managed by Terraform
rather than created manually because:

- **Reproducibility** — destroying and re-creating a server produces exactly the same
  layout every time.
- **Documentation-as-code** — the channel structure is visible in version control, not
  buried in a GUI.
- **Onboarding** — a new deployment gets a fully configured server in one `terraform apply`.

The Terraform provider used is
[`Lucky3028/discord`](https://registry.terraform.io/providers/Lucky3028/discord),
which manages Discord resources via a bot token.

## What Terraform Manages

- A set of Discord text channels for OpenClaw communication (commands, logs, alerts)
- Channel categories grouping related channels
- Channel permissions (private to the bot and allowlisted users)

The specific channel names and structure are defined in
[`terraform/discord/main.tf`](../terraform/discord/main.tf).

## Prerequisites

1. A Discord server you own or admin (Terraform does not create the server itself).
2. A Discord bot created via the
   [Discord Developer Portal](https://discord.com/developers/applications), invited
   to the server with **Manage Channels** and **Manage Roles** permissions.
3. The bot token and server ID stored in 1Password:

   ```bash
   # Store the bot token
   op item create --vault OpenClaw --category login \
     --title discord credential="Bot your_token_here"

   # Add the server ID to the same item
   op item edit discord --vault OpenClaw "server_id[text]=YOUR_DISCORD_SERVER_ID"
   ```

4. A 1Password service account token exported:

   ```bash
   export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
   ```

## Usage

```bash
cd terraform/discord
terraform init
terraform plan
terraform apply
```

After `apply`, re-run the Ansible deploy (`make deploy`) so that the guild and channel
IDs are picked up by the `openclaw_config` role.

For full operational details — variable names, tfvars customisation, and state
management — see
[`terraform/discord/README.md`](../terraform/discord/README.md).

## Relationship to Ansible

Terraform provisions the Discord server layout **once**, before the first Ansible
deploy. After that, Ansible reads the Discord credentials from 1Password and writes
them to OpenClaw's `.env` file. The two tools are complementary:

| Tool | Responsibility |
|------|---------------|
| Terraform | Discord server structure (channels, categories, permissions) |
| Ansible | OpenClaw configuration that references those channels |
| 1Password | Bridge — stores the bot token and IDs that both tools read |
