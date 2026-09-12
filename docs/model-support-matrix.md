# KClaw Model Support Matrix

PDF column reflects native handling via the provider — not LiteLLM modality routing (see note below).

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
| **Claude Sonnet 4.6** | Frontier | 200K | ✅ | ✅ | $3.00 | $15.00 | Confirmed ✅ |

## AWS Bedrock

| Model | Type | Context | Images | PDFs | Cost In | Cost Out | Status |
|---|---|---|---|---|---|---|---|
| **Claude Sonnet 4.6** | Frontier | 200K | ✅ | ✅ | $3.00 | $15.00 | Confirmed ✅ |
| **Claude Sonnet 5** | Frontier | 200K | ✅ | ✅ | $2.00 | $10.00 | Confirmed ✅ |
| **GLM-5** | Open-weight | TBC | ✅ | ✅ | TBC | TBC | Confirmed ✅ |

## Recommended Deployment Configs

| Config | Provider | Primary | PDF | Cost (est.) | Needs Code Change |
|---|---|---|---|---|---|
| **Budget** | OpenRouter | GPT-5.6 Luna | Built-in | $0.20/$1.20 | No |
| **Balanced** | OpenRouter | Meta Muse Spark 1.3 | Built-in | $1.25/$4.25 | No |
| **Single-model safe** | OpenRouter | Gemini 3.8 Flash | Built-in | $0.75/$3.75 | No |
| **Premium** | OpenRouter | Sonnet 4.6 | Built-in | $3.00/$15.00 | No |
| **Premium (Bedrock)** | Bedrock | Sonnet 4.6 | Built-in | $3.00/$15.00 | No |

## PDF Routing Note

LiteLLM `modality_routing: true` detects image blocks but **not** Anthropic `document` blocks. All two-model PDF configs require a ~10 line code change in `container/agent-runner/src/index-http-v2.ts` to detect PDF attachments and send `model: pdf-model` instead of `model: primary`.

Until that change is made, only single-model configs handle PDFs reliably.

## Models Still to Test

### OpenRouter
- ~~GPT-5.6 Luna~~ — Confirmed ✅ text, images, PDFs all working
- ~~Qwen3.8 Max~~ — PDFs fail via OpenRouter (Alibaba backend rejects document blocks)
- ~~Meta Muse Spark 1.3~~ — Confirmed ✅ text, images, PDFs all working
- ~~Kimi K3~~ — Confirmed ✅ text, images, PDFs all working

### AWS Bedrock
- ~~Claude Sonnet 4.6~~ — Confirmed ✅ text, images, PDFs all working
- ~~Claude Sonnet 5~~ — Confirmed ✅ text, images, PDFs all working
- ~~GLM-5~~ — Confirmed ✅ text, images, PDFs all working
