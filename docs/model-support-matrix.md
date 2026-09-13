# KClaw Model Support Matrix

## Recommended Model Requirements

When selecting a model for KClaw, we recommend all three modalities are supported natively by a single model:

- **1M token context window** — agents accumulate long conversation histories, tool outputs, and file content. Anything less than 1M creates hard limits on complex workflows.
- **Image support** — users regularly share screenshots, diagrams, and photos directly in chat.
- **PDF support** — users share documents, reports, and invoices. PDF handling requires the model to process Anthropic `document` blocks natively via LiteLLM/OpenRouter or Bedrock. Many models claim PDF support but reject Anthropic document blocks in practice — see test results below.

Models that fail any of these three are tracked in the matrix but do not have saved configs.

---

PDF column reflects native handling via the provider. Pricing as of Sep 12, 2026.

## OpenRouter

| Model | Type | Context | Images | PDFs | Cost In | Cost Out | Status |
|---|---|---|---|---|---|---|---|
| **GLM-5V-Turbo** | Open-weight | 1M | ✅ | ✅² | $1.20 | $4.00 | Confirmed ✅ (PDFs via Haiku routing) |
| **DeepSeek V4.1 Flash** | Open-weight | 1M | ✅² | ✅² | $0.07 | $0.28 | Confirmed ✅ (images/PDFs via Haiku routing) |
| **GLM-5.3-Flash** | Open-weight | 1M | ✅ | ✅² | $0.15 | $0.50 | Confirmed ✅ (PDFs via Haiku routing) |
| **Qwen3.8 Max** | Open-weight | 1M | ✅ | ✅² | $2.00 | $6.00 | Confirmed ✅ (PDFs via Haiku routing) |
| **GPT-5.6 Luna** | Frontier | 1M | ✅ | ✅ | $0.20 | $1.20 | Confirmed ✅ |
| **Meta Muse Spark 1.3** | Open-weight | 1M | ✅ | ✅ | $1.25 | $4.25 | Confirmed ✅ (requires 18+ attestation) |
| **Kimi K3** | Open-weight | 1M | ✅ | ✅ | $2.38 | $13.30 | Confirmed ✅ |
| **Gemini 3.8 Flash** | Frontier | 1M | ✅ | ✅ | $0.75 | $3.75 | Confirmed ✅ |
| **Claude Sonnet 4.6** | Frontier | 1M | ✅ | ✅ | $3.00 | $15.00 | Confirmed ✅ |

² Images and PDFs route to Haiku 4.5 via complexity_router COMPLEX tier — no code change required. Haiku 4.5 acts as a universal modality handler for any paired primary model.

## AWS Bedrock

| Model | Type | Context | Images | PDFs | Cost In | Cost Out | Status |
|---|---|---|---|---|---|---|---|
| **Claude Sonnet 4.6** | Frontier | 1M | ✅ | ✅ | $3.00 | $15.00 | Confirmed ✅ |
| **Claude Sonnet 5** | Frontier | 1M | ✅ | ✅ | $2.00 | $10.00 | Confirmed ✅ |
| **GLM-5** | Open-weight | TBC | ✅ | ✅ | $1.00 | $3.20 | Confirmed ✅ |

## Recommended Deployment Configs

| Config | Provider | Primary | PDF Model | Cost In | Cost Out |
|---|---|---|---|---|---|
| **Ultra Budget Two-Model** | OpenRouter | DeepSeek V4.1 Flash | Haiku 4.5 | $0.07 | $0.28 |
| **Budget Two-Model** | OpenRouter | GLM-5V-Turbo | Haiku 4.5 | $1.20 | $4.00 |
| **Budget Two-Model Alt** | OpenRouter | GLM-5.3-Flash | Haiku 4.5 | $0.15 | $0.50 |
| **Balanced Two-Model** | OpenRouter | Qwen3.8 Max | Haiku 4.5 | $2.00 | $6.00 |
| **Budget** | OpenRouter | GPT-5.6 Luna | Built-in | $0.20 | $1.20 |
| **Balanced** | OpenRouter | Gemini 3.8 Flash | Built-in | $0.75 | $3.75 |
| **Balanced+** | OpenRouter | Meta Muse Spark 1.3 | Built-in | $1.25 | $4.25 |
| **Performance** | OpenRouter | Kimi K3 | Built-in | $2.38 | $13.30 |
| **Premium** | OpenRouter | Sonnet 4.6 | Built-in | $3.00 | $15.00 |
| **Budget (Bedrock)** | Bedrock | GLM-5 | Built-in | $1.00 | $3.20 |
| **Premium Bedrock Alt** | Bedrock | Sonnet 5 | Built-in | $2.00 | $10.00 |
| **Premium (Bedrock)** | Bedrock | Sonnet 4.6 | Built-in | $3.00 | $15.00 |


