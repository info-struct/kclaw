# KClaw Model Support Matrix

Models evaluated for use as the primary LiteLLM model. All require 1M context, text, and image support minimum. PDF column reflects native handling via OpenRouter — not LiteLLM modality routing (see note below).

| Model | Type | Context | Images | PDFs | Cost In | Cost Out | Status |
|---|---|---|---|---|---|---|---|
| **DeepSeek V4.1 Flash** | Open-weight | 1M | ❌ | ❌ | $0.07 | $0.28 | Tested — text only |
| **GLM-5.3-Flash** | Open-weight | 1M | ✅ | ❌ | $0.15 | $0.50 | Tested ✅ |
| **MiniMax-M3** | Open-weight | 1M | ✅ | ❌ | $0.30 | $1.20 | Tested ✅ |
| **GPT-5.6 Luna** | Frontier | 1M | ✅ | ✅ | $0.20 | $1.20 | Confirmed ✅ |
| **Qwen3.8 Max** | Open-weight | 1M | ✅ | ❌ | TBC | TBC | Tested — PDFs fail via OpenRouter |
| **Meta Muse Spark 1.3** | Open-weight | 1M | ✅ | ✅ | $1.25 | $4.25 | Confirmed ✅ |
| **Kimi K3** | Open-weight | 1M | ✅ | ❌² | $2.38 | $13.30 | Not tested |
| **Gemini 3.8 Flash** | Frontier | 1M | ✅ | ✅ | $0.75 | $3.75 | Confirmed ✅ |
| **Claude Sonnet 4.6** | Frontier | 200K | ✅ | ✅ | $3.00 | $15.00 | Confirmed ✅ |

² Kimi K3 supports text+images+video — no PDF mention on OpenRouter

## Recommended Deployment Configs

| Config | Primary | PDF | Cost (est.) | Needs Code Change |
|---|---|---|---|---|
| **Budget** | GLM-5.3-Flash | Sonnet 4.6 | ~$0.15/$0.50 + PDF overage | Yes |
| **Balanced** | MiniMax-M3 | Sonnet 4.6 | ~$0.30/$1.20 + PDF overage | Yes |
| **Single-model safe** | Gemini 3.8 Flash | Built-in | $0.75/$3.75 | No |
| **Premium** | Sonnet 4.6 | Built-in | $3.00/$15.00 | No |

## PDF Routing Note

LiteLLM `modality_routing: true` detects image blocks but **not** Anthropic `document` blocks. All two-model PDF configs require a ~10 line code change in `container/agent-runner/src/index-http-v2.ts` to detect PDF attachments and send `model: pdf-model` instead of `model: primary`.

Until that change is made, only single-model configs (Gemini 3.8 Flash, Sonnet 4.6) handle PDFs reliably.

## Models Still to Test

- ~~GPT-5.6 Luna~~ — Confirmed ✅ text, images, PDFs all working
- ~~Qwen3.8 Max~~ — PDFs fail via OpenRouter (Alibaba backend rejects document blocks)
- ~~Meta Muse Spark 1.3~~ — Confirmed ✅ text, images, PDFs all working (requires 18+ attestation on OpenRouter)
- Kimi K3 — verify image/PDF handling
