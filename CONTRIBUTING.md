# Contributing

Thanks for helping improve the OpenClaw VPS setup.

## Quick Start

1. Fork the repo and create a feature branch.
2. Use the dev container if possible for a consistent toolchain.
3. Keep changes focused and include updates to docs where needed.

## Development Notes

- Ansible content lives under `ansible/`.
- Terraform content (Discord resources) lives under `terraform/discord/`.
- Use `ansible/secrets-EXAMPLE.yml` as a template. Never commit real secrets.

## Testing

From the repo root:

```bash
./test-deploy.sh
```

From the Ansible directory:

```bash
make test
```

## Pull Requests

- Describe the problem and the approach.
- Include any relevant commands or output.
- Add or update documentation when behavior changes.

## Code of Conduct

This project follows the Contributor Covenant. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
