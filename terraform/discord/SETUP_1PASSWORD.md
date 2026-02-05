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
   - Grant access to the vault containing your Discord credentials
   - Recommended: Create a dedicated "Infrastructure" vault
   - Set permissions to **Read** only (Terraform only needs to read secrets)

4. **Save the Token**
   - Copy the service account token (starts with `ops_...`)
   - **CRITICAL**: Save this token securely - you cannot retrieve it again!
   - Store it temporarily in a secure note or password manager

## Step 2: Create Discord Credentials Item in 1Password

1. **Open 1Password**
   - Navigate to the vault you granted access to (e.g., "Infrastructure")

2. **Create New Item**
   - Click **New Item** > **Login** (or **Password**)
   - Title: `Discord OpenClaw Bot`

3. **Add Required Fields**
   Configure the item with these exact field names:

   - **username**: Your Discord bot token
     - Example: `MTIzNDU2Nzg5MDEyMzQ1Njc4.GhABCD.1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ`
     - Get this from: https://discord.com/developers/applications

   - **password**: Your Discord server (guild) ID
     - Example: `1234567890123456789`
     - To find: Enable Developer Mode in Discord, right-click server, "Copy Server ID"

4. **Optional: Add Notes**
   - Add notes about the bot's purpose, permissions, or server details
   - Document when the bot token was created

5. **Save the Item**

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
op item get "Discord OpenClaw Bot" --vault "Infrastructure"
```

Expected output should show your item details.

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
   onepassword_vault        = "Infrastructure"
   onepassword_discord_item = "Discord OpenClaw Bot"
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

## Troubleshooting

### Error: "item not found"

**Problem**: Terraform can't find the 1Password item.

**Solutions**:
- Verify item name matches exactly: `Discord OpenClaw Bot`
- Check vault name is correct: `Infrastructure`
- Ensure service account has access to the vault
- Run: `op item get "Discord OpenClaw Bot" --vault "Infrastructure"` to test

### Error: "unauthorized"

**Problem**: Service account token is invalid or expired.

**Solutions**:
- Verify `OP_SERVICE_ACCOUNT_TOKEN` is set: `echo $OP_SERVICE_ACCOUNT_TOKEN`
- Check token hasn't been revoked in 1Password
- Regenerate service account token if needed

### Error: "field not found"

**Problem**: Required fields (username/password) missing from 1Password item.

**Solutions**:
- Open item in 1Password
- Verify **username** field contains bot token
- Verify **password** field contains server ID
- Field names are case-sensitive

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
   - Limit to specific vaults needed for Terraform
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
   - Use different vaults for each environment
   - Never share tokens between environments

5. **Token Storage**
   - Never commit tokens to git
   - Use environment variables or CI/CD secrets
   - Don't store in plain text files
   - Don't share via email or chat

## Alternative: Using 1Password CLI with Terraform

If you prefer not to use service accounts, you can use the 1Password CLI with your personal account:

```bash
# Sign in to 1Password CLI
eval $(op signin)

# Run Terraform with op run wrapper
op run --env-file=".env.1password" -- terraform apply
```

Create `.env.1password`:
```
OP_SERVICE_ACCOUNT_TOKEN=op://Infrastructure/Discord OpenClaw Bot/credential
```

This approach is good for local development but service accounts are recommended for CI/CD.
