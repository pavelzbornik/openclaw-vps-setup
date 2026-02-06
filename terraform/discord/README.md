# OpenClaw Discord Server - Terraform Configuration

This directory contains Terraform configuration to provision and manage the OpenClaw Discord server structure using **1Password** for secure secret management.

## Prerequisites

1. **1Password Service Account**
   - Create a service account in 1Password with access to your vault
   - Save the service account token ( )
   - See [1Password Service Account Documentation](https://developer.1password.com/docs/service-accounts/)

2. **Discord Bot Setup**
   - Go to [Discord Developer Portal](https://discord.com/developers/applications)
   - Create a new application
   - Go to the "Bot" section and create a bot
   - Copy the bot token
   - Under "Bot Permissions", select:
     - Manage Channels
     - Manage Roles (optional, for future permissions setup)

3. **Store Secrets in 1Password**
   - Create an item in your 1Password vault (default: "Infrastructure" vault)
   - Item name: "Discord OpenClaw Bot" (or customize via variables)
   - Add fields:
     - **username**: Your Discord bot token
     - **password**: Your Discord server ID

   To find your server ID:
   - Enable Developer Mode in Discord (User Settings > Advanced > Developer Mode)
   - Right-click your server icon and select "Copy Server ID"

4. **Invite Bot to Server**
   - In Developer Portal, go to "OAuth2" > "URL Generator"
   - Select scopes: `bot`
   - Select permissions: `Manage Channels`, `Manage Roles`
   - Copy the generated URL and open it in browser
   - Select your Discord server and authorize

5. **Install Terraform**
   ```bash
   # macOS
   brew install terraform

   # Ubuntu/Debian
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   ```

## Setup

## Setup

1. **Set 1Password Service Account Token**
   ```bash
   export OP_SERVICE_ACCOUNT_TOKEN="your-service-account-token"
   ```

2. **Configure Variables (Optional)**
   ```bash
   cd terraform/discord
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars if using different vault/item names
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Preview Changes**
   ```bash
   terraform plan
   ```

5. **Apply Configuration**
   ```bash
   terraform apply
   ```

   Review the plan and type `yes` to confirm.

## Channel Structure

This configuration creates the following structure:

```
OpenClaw Discord Server
├── AI WORKSPACE/
│   ├── #coding - Programming, debugging, and technical documentation
│   ├── #research - Information gathering and analysis
│   ├── #writing - Content creation and editing
│   ├── #daily-planning - Tasks, calendar, and daily reminders
│   └── #home-automation - Smart home commands and automation
├── PROJECTS/
│   ├── #openclaw-dev - OpenClaw development and discussions
│   └── #infrastructure - Infrastructure, deployment, and DevOps
├── GENERAL/
│   ├── #announcements - Important announcements and updates
│   └── #general - General discussion and chat
└── LOGS/
    ├── #bot-logs - Bot activity and system logs
    └── #audit-logs - Audit trail for important actions
```

## Managing Changes

### Adding a New Channel

Edit `main.tf` and add a new resource:

```hcl
resource "discord_text_channel" "new_channel" {
  name      = "new-channel"
  server_id = var.discord_server_id
  category  = discord_category_channel.ai_workspace.id
  topic     = "Description of the channel"
  position  = 6
}
```

Then run:
```bash
terraform plan
terraform apply
```

### Modifying Existing Channels

Edit the relevant resource in `main.tf` and apply changes:
```bash
terraform apply
```

### Deleting Channels

Remove the resource from `main.tf` and apply:
```bash
terraform apply
```

**Warning**: This will permanently delete the channel and its history!

## Useful Commands

```bash
# Show current state
terraform show

# List all resources
terraform state list

# Get detailed info about a resource
terraform state show discord_text_channel.coding

# Format configuration files
terraform fmt

# Validate configuration
terraform validate

# Destroy all resources (use with caution!)
terraform destroy
```

## Environment Variables (Alternative to tfvars)

Instead of using `terraform.tfvars`, you can set environment variables:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="your-service-account-token"
export TF_VAR_onepassword_vault="Infrastructure"
export TF_VAR_onepassword_discord_item="Discord OpenClaw Bot"
terraform apply
```

## CI/CD Integration

For automated deployments with GitHub Actions:

```yaml
name: Deploy Discord Infrastructure

on:
  push:
    branches: [ main ]
    paths: [ 'terraform/discord/**' ]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        working-directory: terraform/discord
        run: terraform init

      - name: Terraform Plan
        working-directory: terraform/discord
        run: terraform plan
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        working-directory: terraform/discord
        run: terraform apply -auto-approve
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
```

Store your 1Password service account token in GitHub Secrets as `OP_SERVICE_ACCOUNT_TOKEN`.

## Troubleshooting

### Bot Missing Permissions
```
Error: API error: Missing Permissions
```
**Solution**: Ensure bot has "Manage Channels" permission in server settings.

### Invalid Token
```
Error: HTTP 401 Unauthorized
```
**Solution**: Check that your bot token is correct and hasn't been regenerated.

### Rate Limiting
```
Error: HTTP 429 Too Many Requests
```
**Solution**: Discord API has rate limits. Wait a few minutes and try again.

### State Lock Issues
```
Error: Error acquiring the state lock
```
**Solution**: If previous run was interrupted:
```bash
terraform force-unlock <LOCK_ID>
```

## Security Notes

- **Never commit** `terraform.tfvars` or `*.tfstate` files to version control
- Use 1Password service accounts for secure secret management
- Store `OP_SERVICE_ACCOUNT_TOKEN` in CI/CD secret stores (GitHub Secrets, etc.)
- Rotate service account tokens periodically
- Use separate service accounts for dev/staging/production environments
- Limit service account access to only required vaults and items

## Additional Resources
Terraform 1Password Provider Docs](https://registry.terraform.io/providers/1Password/onepassword/latest/docs)
- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/)
- [
- [Terraform Discord Provider Docs](https://registry.terraform.io/providers/Lucky3028/discord/latest/docs)
- [Discord Developer Portal](https://discord.com/developers/docs)
- [Terraform Documentation](https://www.terraform.io/docs)
