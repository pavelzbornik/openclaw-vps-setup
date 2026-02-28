output "ai_workspace_category_id" {
  description = "ID of the AI WORKSPACE category"
  value       = discord_category_channel.ai_workspace.id
}

output "projects_category_id" {
  description = "ID of the PROJECTS category"
  value       = discord_category_channel.projects.id
}

output "general_category_id" {
  description = "ID of the GENERAL category"
  value       = discord_category_channel.general.id
}

output "logs_category_id" {
  description = "ID of the LOGS category"
  value       = discord_category_channel.logs.id
}

output "channel_ids" {
  description = "Map of channel names to their IDs"
  value = {
    coding          = discord_text_channel.coding.id
    research        = discord_text_channel.research.id
    writing         = discord_text_channel.writing.id
    daily_planning  = discord_text_channel.daily_planning.id
    home_automation = discord_text_channel.home_automation.id
    openclaw_dev    = discord_text_channel.openclaw_dev.id
    infrastructure  = discord_text_channel.infrastructure.id
    announcements   = discord_text_channel.announcements.id
    general         = discord_text_channel.general_chat.id
    bot_logs        = discord_text_channel.bot_logs.id
    audit_logs      = discord_text_channel.audit_logs.id
  }
}
