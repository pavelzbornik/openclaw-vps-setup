# 1Password provider configuration
# Uses OP_SERVICE_ACCOUNT_TOKEN environment variable
provider "onepassword" {}

# Fetch Discord credentials from 1Password
data "onepassword_item" "discord_bot" {
  vault = var.onepassword_vault
  title = var.onepassword_discord_item
}

provider "discord" {
  token = data.onepassword_item.discord_bot.username
}

# Local value for server ID from 1Password
locals {
  discord_server_id = data.onepassword_item.discord_bot.password
}

# AI WORKSPACE Category
resource "discord_category_channel" "ai_workspace" {
  name      = "AI WORKSPACE"
  server_id = local.discord_server_id
  position  = 1
}

resource "discord_text_channel" "coding" {
  name      = "coding"
  server_id = local.discord_server_id
  category  = discord_category_channel.ai_workspace.id
  topic     = "Programming, debugging, and technical documentation"
  position  = 1
}

resource "discord_text_channel" "research" {
  name      = "research"
  server_id = local.discord_server_id
  category  = discord_category_channel.ai_workspace.id
  topic     = "Information gathering and analysis"
  position  = 2
}

resource "discord_text_channel" "writing" {
  name      = "writing"
  server_id = local.discord_server_id
  category  = discord_category_channel.ai_workspace.id
  topic     = "Content creation and editing"
  position  = 3
}

resource "discord_text_channel" "daily_planning" {
  name      = "daily-planning"
  server_id = local.discord_server_id
  category  = discord_category_channel.ai_workspace.id
  topic     = "Tasks, calendar, and daily reminders"
  position  = 4
}

resource "discord_text_channel" "home_automation" {
  name      = "home-automation"
  server_id = local.discord_server_id
  category  = discord_category_channel.ai_workspace.id
  topic     = "Smart home commands and automation"
  position  = 5
}

# PROJECTS Category
resource "discord_category_channel" "projects" {
  name      = "PROJECTS"
  server_id = local.discord_server_id
  position  = 2
}

resource "discord_text_channel" "openclaw_dev" {
  name      = "openclaw-dev"
  server_id = local.discord_server_id
  category  = discord_category_channel.projects.id
  topic     = "OpenClaw development and discussions"
  position  = 1
}

resource "discord_text_channel" "infrastructure" {
  name      = "infrastructure"
  server_id = local.discord_server_id
  category  = discord_category_channel.projects.id
  topic     = "Infrastructure, deployment, and DevOps"
  position  = 2
}

# GENERAL Category
resource "discord_category_channel" "general" {
  name      = "GENERAL"
  server_id = local.discord_server_id
  position  = 3
}

resource "discord_text_channel" "announcements" {
  name      = "announcements"
  server_id = local.discord_server_id
  category  = discord_category_channel.general.id
  topic     = "Important announcements and updates"
  position  = 1
}

resource "discord_text_channel" "general_chat" {
  name      = "general"
  server_id = local.discord_server_id
  category  = discord_category_channel.general.id
  topic     = "General discussion and chat"
  position  = 2
}

# LOGS Category
resource "discord_category_channel" "logs" {
  name      = "LOGS"
  server_id = local.discord_server_id
  position  = 4
}

resource "discord_text_channel" "bot_logs" {
  name      = "bot-logs"
  server_id = local.discord_server_id
  category  = discord_category_channel.logs.id
  topic     = "Bot activity and system logs"
  position  = 1
}

resource "discord_text_channel" "audit_logs" {
  name      = "audit-logs"
  server_id = local.discord_server_id
  category  = discord_category_channel.logs.id
  topic     = "Audit trail for important actions"
  position  = 2
}
