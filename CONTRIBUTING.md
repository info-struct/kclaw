# Contributing

## License

KClaw is licensed under [FSL-1.1-ALv2](LICENSE.md). By submitting a contribution you agree that your changes will be released under the same license.

## What we accept

- Bug fixes and correctness improvements
- Documentation improvements and corrections
- New model configs that pass all three requirements (1M context, images, PDFs) — see [model-support-matrix.md](docs/model-support-matrix.md)
- New integration guides (channels, MCP servers, identity providers)

We do not accept contributions that:
- Add external runtime dependencies without discussion
- Change core architecture or multi-tenancy model without a prior issue

## How to contribute

1. Open an issue first for anything beyond a small fix — describe the problem and your proposed approach
2. Fork the repo and create a branch from `main`
3. Make your changes and test them on a running cluster
4. Submit a pull request with a clear description of what changed and why

## Model configs

New model configs must be tested end-to-end before submitting — text, image, and PDF all passing. Include the model's cost per 1M tokens (in/out) and add a row to `docs/model-support-matrix.md`. Configs that fail any of the three modalities will not be merged.

## Reporting bugs

Open a GitHub issue with:
- KClaw version (from `kclaw-installer.tar.gz` filename or git tag)
- Platform (ARM/x86, cloud provider)
- Steps to reproduce
- Relevant pod logs (`kubectl logs -l app=<component> -n kclaw`)

For security issues, see [SECURITY.md](SECURITY.md).
