variable "onepassword_vault" {
  description = "1Password vault name where Discord secrets are stored"
  type        = string
  default     = "Infrastructure"
}

variable "onepassword_discord_item" {
  description = "1Password item name containing Discord credentials"
  type        = string
  default     = "Discord OpenClaw Bot"
}
