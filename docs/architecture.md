# Architecture

This document describes the architecture of the openclaw-vps-setup project.
The diagrams follow the C4 model levels: System Context → Containers → Components.

---

## Level 1 — System Context

Who uses the system and what external services does it depend on.

```mermaid
flowchart TB
    operator(["👤 Operator"])
    enduser(["👤 End User"])

    subgraph sys["OpenClaw VPS Setup"]
        infra["OpenClaw Infrastructure\nAnsible + Terraform IaC"]
    end

    onepassword[("1Password\nSecrets vault")]
    discord[("Discord API")]
    telegram[("Telegram API")]
    llm[("OpenAI / OpenRouter\nLLM inference")]
    tailscale[("Tailscale\nVPN mesh")]
    s3[("AWS S3\nBackups")]

    operator -->|"Ansible / Terraform"| infra
    enduser -->|"commands"| discord
    enduser -->|"commands"| telegram

    infra -->|"op inject"| onepassword
    infra -->|"Discord bot WebSocket"| discord
    infra -->|"Telegram Bot API"| telegram
    infra -->|"HTTPS REST"| llm
    infra -->|"WireGuard UDP 41641"| tailscale
    infra -->|"encrypted backup"| s3
```

---

## Level 2 — Containers

The major technical building blocks and how they relate.

```mermaid
flowchart TB
    operator(["👤 Operator"])
    enduser(["👤 End User"])

    subgraph ci["Operator Workstation / CI Runner"]
        ansible_ctrl["Ansible Control Node\nPython / Ansible"]
        terraform["Terraform\nHCL"]
    end

    subgraph vm["Production VM — Ubuntu VPS or Hyper-V"]
        openclaw["OpenClaw Agent\nNode.js / pnpm\nport 3000 loopback"]
        nginx["Nginx Gateway Proxy\nports 80 / 443 LAN"]
        samba["Samba File Share\nTCP 445 LAN"]
        op_cli["1Password CLI\nop inject"]
        systemd["systemd\nopenclaw.service"]
        backup_cron["Backup Cron\nbash / cron"]
    end

    subgraph devcontainer["DevContainer — local testing"]
        dc_control["ansible-control\nUbuntu 24.04 + Ansible"]
        dc_target["ubuntu-target\nUbuntu 24.04 + systemd"]
    end

    onepassword[("1Password\nSecrets vault")]
    discord[("Discord API")]
    telegram[("Telegram API")]
    llm[("OpenAI / OpenRouter\nLLM inference")]
    tailscale[("Tailscale\nVPN mesh")]
    s3[("AWS S3\nObject storage")]

    operator -->|"make deploy / GitHub Actions"| ansible_ctrl
    operator -->|"terraform apply"| terraform
    ansible_ctrl -->|"SSH / Ansible"| openclaw
    ansible_ctrl -->|"op CLI - admin token"| onepassword

    enduser -->|"HTTPS port 443"| nginx
    nginx -->|"HTTP localhost:3000"| openclaw
    op_cli -->|"op inject writes .env"| openclaw
    systemd -->|"manages lifecycle"| openclaw
    openclaw --> discord
    openclaw --> telegram
    openclaw --> llm
    openclaw -->|"WireGuard VPN"| tailscale
    backup_cron -->|"encrypted upload"| s3
    backup_cron -->|"op CLI - runtime token"| onepassword

    dc_control -->|"SSH"| dc_target
```

---

## Level 3 — Components: Production VM

The internal components running on the production VM and how data flows between them.

```mermaid
flowchart TB
    operator(["👤 Operator"])
    enduser(["👤 End User (LAN)"])

    onepassword[("1Password")]
    discord[("Discord API")]
    telegram[("Telegram API")]
    llm[("OpenAI / OpenRouter")]
    s3[("AWS S3")]
    tailscale_net[("Tailscale Network")]

    subgraph vm["Production VM"]
        nginx["Nginx\nports 80 / 443"]
        openclaw_proc["openclaw process\nNode.js / pnpm\nport 3000 loopback"]
        samba_proc["smbd / nmbd\nSamba TCP 445 LAN"]
        systemd_unit["openclaw.service\nsystemd"]
        logrotate_conf["logrotate"]
        op_inject["op inject\n1Password CLI"]
        openclaw_json["openclaw.json\nconfig file"]
        env_file[".env\nmaterilaized secrets"]
        backup_script["backup.sh\ndaily cron"]
        tailscale_daemon["tailscaled\nWireGuard daemon"]
    end

    operator -->|"Ansible openclaw_config role"| op_inject
    op_inject -->|"reads op:// references"| onepassword
    op_inject -->|"writes"| env_file
    openclaw_proc -->|"reads"| env_file
    openclaw_proc -->|"reads"| openclaw_json
    systemd_unit -->|"start / stop / restart"| openclaw_proc
    logrotate_conf -->|"rotates logs"| openclaw_proc

    enduser -->|"HTTPS port 443"| nginx
    nginx -->|"HTTP localhost:3000"| openclaw_proc

    openclaw_proc -->|"WebSocket"| discord
    openclaw_proc -->|"HTTPS polling"| telegram
    openclaw_proc -->|"HTTPS REST"| llm

    backup_script -->|"encrypted upload"| s3
    backup_script -->|"reads passphrase + creds"| onepassword

    tailscale_daemon -->|"WireGuard UDP 41641"| tailscale_net
```

---

## Level 3 — Components: Ansible Deployment Pipeline

How `ansible/site.yml` composes roles to build the production VM.

```mermaid
flowchart TB
    operator(["👤 Operator / CI Runner"])
    onepassword[("1Password")]
    vm_target[("Production VM\nor DevContainer")]

    subgraph playbook["ansible/site.yml"]
        pre_tasks["Pre-tasks\nload vault vars · fetch secrets\nwait for SSH · gather facts"]
        role_vendor["openclaw_vendor_base\nNode.js · Tailscale · UFW\nopenclaw user · pnpm · binary"]
        role_common["common\ntimezone · locale · packages"]
        role_op["onepassword\ninstall op CLI"]
        role_config["openclaw_config\nopenclaw.json · .env · op inject\nsystemd service · logrotate"]
        role_gateway["openclaw_gateway_proxy\nNginx · TLS cert · UFW rules\nif openclaw_lan_enabled"]
        role_samba["openclaw_samba\nSamba share · UFW rules\nif openclaw_samba_enabled"]
        post_tasks["Post-tasks\nverify binary · check service"]
    end

    operator -->|"make deploy"| pre_tasks
    pre_tasks -->|"op read"| onepassword
    pre_tasks --> role_vendor
    role_vendor --> role_common
    role_common --> role_op
    role_op --> role_config
    role_config --> role_gateway
    role_gateway -->|"if enabled"| role_samba
    role_samba --> post_tasks
    post_tasks -->|"result"| operator

    role_vendor -->|"configures"| vm_target
    role_common -->|"configures"| vm_target
    role_op -->|"installs on"| vm_target
    role_config -->|"configures"| vm_target
    role_gateway -->|"configures"| vm_target
    role_samba -->|"configures"| vm_target
```

---

## Secrets Architecture

The two-token model used to limit credential exposure on the VM.

```mermaid
flowchart TD
    subgraph operator["Operator / CI Runner"]
        admin_token["Admin Service Account Token\n(OP_SERVICE_ACCOUNT_TOKEN)\nAccess: OpenClaw + OpenClaw Admin vaults"]
    end

    subgraph vault_admin["1Password — OpenClaw Admin vault"]
        runtime_sa["OpenClaw Runtime SA item\ncredential = runtime token"]
        aws_admin["AWS Admin item\naccess_key_id + secret_access_key"]
    end

    subgraph vault_runtime["1Password — OpenClaw vault"]
        discord_item["discord item\ncredential, allowlist, guilds, server_id"]
        openclaw_item["OpenClaw item\nidentity_md, user_md, vscode_ssh_key"]
        gateway_item["OpenClaw Gateway item\ncredential"]
        aws_backup_item["AWS Backup item\naccess_key_id, secret_access_key, s3_bucket, passphrase"]
        tailscale_item["Tailscale item\ncredential"]
        openai_item["OpenAI item\ncredential"]
        samba_item["Samba item\ncredential"]
    end

    subgraph vm["Production VM"]
        runtime_token_file["/etc/openclaw/ops_token\n(runtime token, written at deploy)"]
        env_file[".env\n(materialized secrets)"]
        openclaw_json_file["openclaw.json\n(config with op:// references)"]
        backup_cron_vm["backup.sh cron job"]
        op_inject_vm["op inject (runs at deploy)"]
    end

    admin_token -->|"Ansible pre-tasks: fetch runtime token"| runtime_sa
    admin_token -->|"Ansible pre-tasks: fetch all runtime secrets"| vault_runtime
    runtime_sa -->|"Written to VM by Ansible"| runtime_token_file

    runtime_token_file -->|"Used by op inject at deploy"| op_inject_vm
    op_inject_vm -->|"Reads from"| vault_runtime
    op_inject_vm -->|"Writes materialized secrets to"| env_file

    runtime_token_file -->|"Used by backup cron"| backup_cron_vm
    backup_cron_vm -->|"Reads passphrase + AWS creds from"| aws_backup_item

    style operator fill:#f5f5f5,stroke:#999
    style vault_admin fill:#fff3cd,stroke:#ffc107
    style vault_runtime fill:#d1ecf1,stroke:#17a2b8
    style vm fill:#d4edda,stroke:#28a745
```

**Key properties of the two-token model:**

| Token | Held by | Vault access | Used for |
|-------|---------|-------------|---------|
| Admin service account | Operator / CI | `OpenClaw` + `OpenClaw Admin` (read/write) | Deploy time: fetch all secrets, write runtime token to VM |
| Runtime service account | VM (`/etc/openclaw/ops_token`) | `OpenClaw` only (read) | `op inject` at deploy, daily backup cron |

The VM never holds admin credentials. If the VM is compromised, the blast radius is limited to the `OpenClaw` vault only.

---

## Testing Architecture

How changes are validated before reaching production.

```mermaid
flowchart LR
    subgraph local["Local Development"]
        precommit["pre-commit hooks\nshellcheck · yamllint\nmarkdownlint · ansible-lint\ndetect-secrets"]
        devcontainer["DevContainer\nansible-control → ubuntu-target\nFull systemd, SSH\nFast iteration (~2 min)"]
    end

    subgraph ci["GitHub Actions CI"]
        stage1["Stage 1: pre-commit\nAll hooks\nansible-lint 25.6.1\nansible-core 2.18.4"]
        stage2["Stage 2: Molecule\nDocker containers\nconverge + verify\nFull playbook run"]
    end

    subgraph prod["Production"]
        production["Production VM\nUbuntu VPS / Hyper-V\nmake deploy"]
    end

    local -->|"git push"| ci
    ci -->|"All checks pass"| prod
    stage1 -->|"triggers"| stage2
```
