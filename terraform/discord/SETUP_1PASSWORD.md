# 1Password Setup Guide for Discord Terraform

This guide walks you through setting up 1Password to securely manage your Discord bot credentials for Terraform.

## Step 1: Create a 1Password Service Account

1. **Sign in to 1Password Business**
   - Go to your 1Password account at https://my.1password.com
   - Navigate to **Settings** > **Service Accounts**

2. **Create New Service Account**
   - Click **Create Service Account**
   - Name: `Terraform Discord Bot`
   - Description: `Service account for managing Discord infrastructure with Terraform`

3. **Configure Permissions**
   - Grant access to the **OpenClaw** vault
   - Set permissions to **Read** only (Terraform only needs to read secrets)

4. **Save the Token**
   - Copy the service account token (starts with `ops_...`)
   - **CRITICAL**: Save this token securely - you cannot retrieve it again!
   - Store it temporarily in a secure note or password manager

## Step 2: Update the `discord` Item in 1Password

The `discord` item already exists in the **OpenClaw** vault with the bot token and user allowlist.
You need to add the `server_id` field containing your Discord server (guild) ID.

1. **Find your Discord Server ID**
   - Enable Developer Mode in Discord: **Settings** > **Advanced** > **Developer Mode**
   - Right-click your server icon, then click **Copy Server ID**

2. **Update the `discord` item**
   ```bash
   op item edit discord --vault OpenClaw "server_id[text]=YOUR_DISCORD_SERVER_ID"
   ```
   Replace `YOUR_DISCORD_SERVER_ID` with the ID you copied.

3. **Verify the item has all required fields**
   ```bash
   op item get discord --vault OpenClaw
   ```

   The item should have these fields:
   - **credential** — your Discord bot token (already set)
   - **server_id** — your Discord server (guild) ID ← add/update this
   - **allowlist** — comma-separated user IDs (used by OpenClaw at runtime)
   - **guilds** — comma-separated guild IDs (used by OpenClaw at runtime)

## Step 3: Verify 1Password Setup

Test that the service account can access the item:

```bash
# Export the service account token
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"

# Install 1Password CLI (if not already installed)
# macOS:
brew install 1password-cli

# Ubuntu/Debian:
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli

# Test access
op item get "discord" --vault "OpenClaw"
```

Expected output should show your item details including the `server_id` field.

## Step 4: Configure Terraform

1. **Set Environment Variable**
   ```bash
   export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
   ```

2. **Optional: Add to Shell Profile**
   ```bash
   # Add to ~/.bashrc, ~/.zshrc, or ~/.profile
   echo 'export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **Configure Variables (if using custom names)**

   Create `terraform.tfvars`:
   ```hcl
   onepassword_vault        = "OpenClaw"
   onepassword_discord_item = "discord"
   ```

## Step 5: Initialize and Run Terraform

```bash
cd terraform/discord

# Initialize Terraform (first time only)
terraform init

# Preview what will be created
terraform plan

# Apply the configuration
terraform apply
```

## Step 6: Enable Discord in OpenClaw (post-Terraform)

After Terraform creates the Discord channels, enable the bot in Ansible:

1. Edit `ansible/group_vars/all.yml`:
   ```yaml
   discord:
     enabled: true
   ```

2. Re-deploy:
   ```bash
   cd ansible && make deploy TAGS=openclaw
   ```

## Troubleshooting

### Error: "item not found"

**Problem**: Terraform can't find the 1Password item.

**Solutions**:
- Verify item name matches exactly: `discord`
- Check vault name is correct: `OpenClaw`
- Ensure service account has access to the **OpenClaw** vault
- Run: `op item get "discord" --vault "OpenClaw"` to test

### Error: "unauthorized"

**Problem**: Service account token is invalid or expired.

**Solutions**:
- Verify `OP_SERVICE_ACCOUNT_TOKEN` is set: `echo $OP_SERVICE_ACCOUNT_TOKEN`
- Check token hasn't been revoked in 1Password
- Regenerate service account token if needed

### Error: "field not found"

**Problem**: Required fields missing from 1Password item.

**Solutions**:
- Open the `discord` item in 1Password
- Verify **credential** field contains the bot token
- Verify **server_id** field contains your Discord server ID (not a comma-separated list)
- Run: `op item edit discord --vault OpenClaw "server_id[text]=YOUR_SERVER_ID"`

### Error: "missing provider"

**Problem**: 1Password Terraform provider not installed.

**Solution**:
```bash
terraform init
```

## CI/CD Setup

### GitHub Actions

Store the service account token in GitHub Secrets:

1. Go to repository **Settings** > **Secrets and variables** > **Actions**
2. Click **New repository secret**
3. Name: `OP_SERVICE_ACCOUNT_TOKEN`
4. Value: Your service account token
5. Click **Add secret**

### GitLab CI

Add to GitLab CI/CD Variables:

1. Go to **Settings** > **CI/CD** > **Variables**
2. Click **Add variable**
3. Key: `OP_SERVICE_ACCOUNT_TOKEN`
4. Value: Your service account token
5. Check **Mask variable**
6. Check **Protect variable** (optional)

## Security Best Practices

1. **Principle of Least Privilege**
   - Service account should only have READ access
   - Limit to the **OpenClaw** vault only
   - Don't grant admin permissions

2. **Token Rotation**
   - Rotate service account tokens every 90 days
   - Document rotation schedule
   - Update tokens in all CI/CD systems

3. **Audit Logging**
   - Monitor 1Password activity logs
   - Review service account access regularly
   - Set up alerts for unusual access patterns

4. **Separate Environments**
   - Use different service accounts for dev/staging/prod
   - Never share tokens between environments

5. **Token Storage**
   - Never commit tokens to git
   - Use environment variables or CI/CD secrets
   - Don't store in plain text files
   - Don't share via email or chat
