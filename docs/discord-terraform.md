# Discord Server Provisioning (Terraform)

This repo includes Terraform configuration to create and manage a Discord server layout for OpenClaw.

## Where It Lives

- Terraform code: [terraform/discord](../terraform/discord)
- Full setup guide: [terraform/discord/README.md](../terraform/discord/README.md)

## Quick Start

1. Create a Discord bot and invite it with "Manage Channels" permission.
2. Store the bot token and server ID in 1Password.
3. Export your service account token:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
```

4. Run Terraform:

```bash
cd terraform/discord
terraform init
terraform plan
terraform apply
```

## Notes

- The Terraform config reads the bot token from the `username` field and the server ID from the `password` field in your 1Password item.
- Use `terraform.tfvars` if you want to customize vault and item names.
