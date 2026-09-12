# KClaw Model Support Matrix

## Recommended Model Requirements

When selecting a model for KClaw, we recommend all three modalities are supported natively by a single model:

- **1M token context window** — agents accumulate long conversation histories, tool outputs, and file content. Anything less than 1M creates hard limits on complex workflows.
- **Image support** — users regularly share screenshots, diagrams, and photos directly in chat.
- **PDF support** — users share documents, reports, and invoices. PDF handling requires the model to process Anthropic `document` blocks natively via LiteLLM/OpenRouter or Bedrock. Many models claim PDF support but reject Anthropic document blocks in practice — see test results below.

Models that fail any of these three are tracked in the matrix but do not have saved configs.

---

PDF column reflects native handling via the provider — not LiteLLM modality routing (see note below). Pricing as of Sep 12, 2026.

## OpenRouter

| Model | Type | Context | Images | PDFs | Cost In | Cost Out | Status |
|---|---|---|---|---|---|---|---|
| **DeepSeek V4.1 Flash** | Open-weight | 1M | ❌ | ❌ | $0.07 | $0.28 | Tested — text only |
| **GLM-5.3-Flash** | Open-weight | 1M | ✅ | ❌ | $0.15 | $0.50 | Tested — PDFs fail via OpenRouter |
| **MiniMax-M3** | Open-weight | 1M | ✅ | ❌ | $0.30 | $1.20 | Tested — PDFs fail via OpenRouter |
| **Qwen3.8 Max** | Open-weight | 1M | ✅ | ❌ | TBC | TBC | Tested — PDFs fail via OpenRouter |
| **GPT-5.6 Luna** | Frontier | 1M | ✅ | ✅ | $0.20 | $1.20 | Confirmed ✅ |
| **Meta Muse Spark 1.3** | Open-weight | 1M | ✅ | ✅ | $1.25 | $4.25 | Confirmed ✅ (requires 18+ attestation) |
| **Kimi K3** | Open-weight | 1M | ✅ | ✅ | $2.38 | $13.30 | Confirmed ✅ |
| **Gemini 3.8 Flash** | Frontier | 1M | ✅ | ✅ | $0.75 | $3.75 | Confirmed ✅ |
| **Claude Sonnet 4.6** | Frontier | 1M | ✅ | ✅ | $3.00 | $15.00 | Confirmed ✅ |

## AWS Bedrock

| Model | Type | Context | Images | PDFs | Cost In | Cost Out | Status |
|---|---|---|---|---|---|---|---|
| **Claude Sonnet 4.6** | Frontier | 1M | ✅ | ✅ | $3.00 | $15.00 | Confirmed ✅ |
| **Claude Sonnet 5** | Frontier | 1M | ✅ | ✅ | $2.00 | $10.00 | Confirmed ✅ |
| **GLM-5** | Open-weight | TBC | ✅ | ✅ | $1.00 | $3.20 | Confirmed ✅ |

## Recommended Deployment Configs

All configs below are single-model and handle text, images, and PDFs natively.

| Config | Provider | Model | Cost In | Cost Out |
|---|---|---|---|---|
| **Budget** | OpenRouter | GPT-5.6 Luna | $0.20 | $1.20 |
| **Balanced** | OpenRouter | Gemini 3.8 Flash | $0.75 | $3.75 |
| **Balanced+** | OpenRouter | Meta Muse Spark 1.3 | $1.25 | $4.25 |
| **Performance** | OpenRouter | Kimi K3 | $2.38 | $13.30 |
| **Premium** | OpenRouter | Sonnet 4.6 | $3.00 | $15.00 |
| **Premium (Bedrock)** | Bedrock | Sonnet 4.6 | $3.00 | $15.00 |
| **Premium Bedrock Alt** | Bedrock | Sonnet 5 | $2.00 | $10.00 |
| **Budget (Bedrock)** | Bedrock | GLM-5 | $1.00 | $3.20 |

## PDF Routing Note

LiteLLM `modality_routing: true` detects image blocks but **not** Anthropic `document` blocks. All two-model PDF configs require a ~10 line code change in `container/agent-runner/src/index-http-v2.ts` to detect PDF attachments and send `model: pdf-model` instead of `model: primary`.

Until that change is made, only single-model configs handle PDFs reliably.

