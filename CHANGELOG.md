# Changelog

## [Unreleased]

### Added
- `docs/model-config-guide.md` — step-by-step guide for applying model configs to a running cluster
- `docs/model-support-matrix.md` — full matrix of tested models with context, image, PDF support, and pricing
- Two-model routing configs pairing cheap primary models with Claude Haiku 4.5 for image/PDF support
- AWS Bedrock configs for Claude Sonnet 4.6 and Sonnet 5
- OpenRouter configs: GPT-5.6 Luna, Gemini 3.8 Flash, Meta Muse Spark 1.3, Kimi K3, Claude Sonnet 4.6
- `.gitignore` to prevent accidental commits of secrets and build artifacts

### Changed
- Bedrock model IDs updated to new format without date/version suffix (`us.anthropic.claude-sonnet-4-6`)
- Docker image references in README changed to `YOUR_REGISTRY/` placeholder
- Installation instructions clarified with full prerequisites, md5 verification step, and `install-summary.txt` explanation

### Fixed
- Absolute Windows path in User Guide.md image reference
- Zero-width space characters (Word artifacts) removed from User Guide.md
- FSL license label corrected to `FSL-1.1-ALv2`

### Removed
- MiniMax-M3 configs — provider rejects Anthropic document blocks before LiteLLM routing can intercept
- Bedrock non-Claude model configs — Claude Code SDK extended thinking params conflict with all non-Claude Bedrock models
