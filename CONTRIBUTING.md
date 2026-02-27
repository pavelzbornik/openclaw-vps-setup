# Contributing

Thanks for helping improve the OpenClaw VPS setup. This guide covers everything you
need to go from idea to merged pull request.

For deeper developer guidance — including playbook execution order, 1Password item
structure, and the full list of common commands — see [CLAUDE.md](CLAUDE.md).

## Table of Contents

- [Quick Start](#quick-start)
- [Development Environment](#development-environment)
- [Commit Message Format](#commit-message-format)
- [Branch Naming](#branch-naming)
- [How to Add a Role](#how-to-add-a-role)
- [Documentation Update Checklist](#documentation-update-checklist)
- [Testing Requirements](#testing-requirements)
- [Pull Requests](#pull-requests)

---

## Quick Start

1. Fork the repo and create a branch (see [Branch Naming](#branch-naming) below).
2. Open the repository in the DevContainer for a consistent, pre-configured toolchain.
3. Make your changes, run tests, update docs.
4. Open a pull request.

---

## Development Environment

The recommended way to develop is via the included DevContainer. It provides:

- Ansible + Molecule pre-installed
- A live `ubuntu-target` container to test against
- Pre-commit hooks configured automatically
- All Galaxy collections installed

See [.devcontainer/README.md](.devcontainer/README.md) for setup instructions.

If you prefer a local environment, you need:

- `ansible-core` 2.18.x
- `ansible-lint` 25.6.1
- `molecule` with the Docker driver
- `pre-commit`

Install pre-commit hooks after cloning:

```bash
pre-commit install --hook-type commit-msg --hook-type pre-commit --hook-type pre-push
```

---

## Commit Message Format

This project enforces **Conventional Commits** via a `commit-msg` pre-commit hook.
Every commit message must follow this format:

```
<type>(<optional scope>): <short description>

[optional body]

[optional footer]
```

### Allowed types

| Type | When to use |
|------|-------------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, whitespace (no logic change) |
| `refactor` | Code restructuring without behaviour change |
| `test` | Adding or updating tests |
| `chore` | Build process, dependency updates, tooling |
| `build` | Changes to CI or build system |
| `ci` | CI/CD pipeline changes |
| `perf` | Performance improvement |
| `revert` | Reverting a previous commit |

### Examples

```
feat(samba): add Samba LAN file-drop share
fix(ci): pin ansible-core to 2.18.4 to avoid loader bug
docs(readme): fix outdated inventory path
chore(vendor): update openclaw-ansible submodule
```

The hook will reject commits that don't match the pattern. Fix the message with:

```bash
git commit --amend
```

---

## Branch Naming

Use a prefix that matches the type of change. The CI pipeline triggers on branches
matching these patterns:

| Prefix | Use for |
|--------|---------|
| `feature/` | New features |
| `fix/` | Bug fixes |
| `docs/` | Documentation-only changes |
| `claude/` | AI-assisted changes |

Examples: `feature/s3-backup`, `fix/molecule-systemd`, `docs/firewall-port-table`

---

## How to Add a Role

Follow these steps when adding a new Ansible role to the project.

### 1. Create the role directory

```bash
cd ansible
ansible-galaxy role init roles/<role-name>
```

Remove boilerplate files you don't need (vars, defaults with no content, etc.).

### 2. Wire it into `site.yml`

Add the role to the appropriate play in `ansible/site.yml`. Roles run in order, so
place it after its dependencies (e.g., after `onepassword` if it needs `op`).

Tag the role so it can be deployed independently:

```yaml
- role: your_role_name
  tags: [your_tag]
```

### 3. Add variables to `group_vars/all.yml`

Define defaults for any role variables in `ansible/group_vars/all.yml`. Use a
consistent prefix (e.g., `openclaw_` for roles in this project).

### 4. Add Molecule tests

Add a test scenario in `ansible/molecule/default/`. At minimum, assert that:

- The role runs without errors (converge)
- The key outcomes are true (verify)

### 5. Update documentation

See the [Documentation Update Checklist](#documentation-update-checklist) below — it
lists every doc file that needs updating when a role is added.

---

## Documentation Update Checklist

When implementing any new feature, role, playbook, or variable, update the following
files **as part of the same task**:

| File | Update when |
|------|-------------|
| `README.md` | New role, capability, or feature flag added |
| `ansible/README.md` | New role (directory tree + Roles section + 1Password table if applicable) |
| `ansible/QUICKSTART.md` | New 1Password item required, new post-deploy verification step, or new optional setup step |
| `CLAUDE.md` — Playbook Execution Order | New role added to `site.yml` |
| `CLAUDE.md` — 1Password Item Structure | New 1Password vault item added |
| `CLAUDE.md` — Common Commands | New deploy tag or one-time setup command added |
| `docs/firewall.md` | New ports opened by UFW |
| `CHANGELOG.md` | Any user-visible change |

---

## Testing Requirements

All pull requests must pass the following checks. The CI pipeline enforces them
automatically.

### 1. Pre-commit hooks

```bash
pre-commit run --all-files
```

This runs `shellcheck`, `yamllint`, `markdownlint`, `ansible-lint`, and
`detect-secrets`. Fix all failures before pushing.

### 2. Molecule tests

```bash
cd ansible && molecule test
```

Molecule runs a full create → converge → verify → destroy cycle in Docker. If Docker
is not available in your environment, explain why in the PR description — the CI
pipeline will still run Molecule.

If your change is documentation-only, Molecule is not required but pre-commit still
must pass.

### 3. DevContainer smoke test (recommended)

For Ansible role changes, do a quick end-to-end test against the live `ubuntu-target`:

```bash
./test-deploy.sh --check   # Dry-run
./test-deploy.sh            # Deploy
```

---

## Pull Requests

- **Title**: use Conventional Commits format (`feat: ...`, `fix: ...`, etc.)
- **Description**: explain the problem, the approach, and any trade-offs
- **Docs**: confirm you've ticked the [Documentation Update Checklist](#documentation-update-checklist)
- **Tests**: include test output or explain why tests don't apply
- **Secrets**: never include real tokens, passwords, or keys — use `op://` references
  or Ansible Vault

Small, focused PRs are easier to review and merge faster. If you're unsure about the
approach, open a draft PR early and ask for feedback.
