# Model Config Guide

KClaw uses LiteLLM as a model proxy. The `model-config/` directory contains ready-to-use config files for different providers and price tiers. This guide walks through how to apply them to a running cluster.

---

## How it works

LiteLLM reads its config from a Kubernetes ConfigMap (`litellm-config`) and credentials from a Secret (`litellm-secrets`), both in the `default` namespace. To switch models you:

1. Update the ConfigMap with the new config file contents
2. Ensure the required API keys are in the Secret
3. Restart the LiteLLM pod to pick up the changes

---

## Picking a config

See [model-support-matrix.md](model-support-matrix.md) for a full comparison. Quick reference:

| File | Provider | Cost In/Out (per 1M) | Notes |
|---|---|---|---|
| `openrouter-gpt-5.6-luna.yaml` | OpenRouter | $0.20 / $1.20 | Budget, all modalities |
| `openrouter-gemini-3.8-flash.yaml` | OpenRouter | $0.75 / $3.75 | Balanced, all modalities |
| `openrouter-muse-spark-1.3.yaml` | OpenRouter | $1.25 / $4.25 | Requires 18+ attestation on OpenRouter |
| `openrouter-kimi-k3.yaml` | OpenRouter | $2.38 / $13.30 | Performance tier |
| `openrouter-sonnet-4.6.yaml` | OpenRouter | $3.00 / $15.00 | Premium |
| `DeepSeek-V4.1-Flash-Haiku.yaml` | OpenRouter | $0.07 / $0.28 | Ultra budget, two-model routing |
| `GLM-5.3-Flash-Haiku.yaml` | OpenRouter | $0.15 / $0.50 | Budget two-model routing |
| `GLM-5V-Turbo-Haiku.yaml` | OpenRouter | $1.20 / $4.00 | Two-model routing |
| `Qwen3.8-Max-Haiku.yaml` | OpenRouter | $2.00 / $6.00 | Balanced two-model routing |
| `bedrock-sonnet-4.6.yaml` | AWS Bedrock | $3.00 / $15.00 | No OpenRouter account needed |
| `bedrock-sonnet-5.yaml` | AWS Bedrock | $2.00 / $10.00 | Best Bedrock value |

---

## Required secrets by provider

The `litellm-secrets` Secret must contain the keys your chosen config references.

**OpenRouter configs** — requires `OPENROUTER_API_KEY`:
```
OPENROUTER_API_KEY=sk-or-...
```

**Bedrock configs** — requires AWS credentials:
```
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION_NAME=us-east-1
```

`LITELLM_MASTER_KEY` and `DATABASE_URL` are always required and are set during initial install — you do not need to change them when switching models.

---

## Applying a config

### Step 1 — Update the Secret (if switching providers)

If you are switching from OpenRouter to Bedrock (or vice versa), add the new provider's keys to the secret:

```bash
# Add or update keys in litellm-secrets
kubectl patch secret litellm-secrets -n default \
  --type merge \
  -p '{"stringData": {
    "OPENROUTER_API_KEY": "sk-or-YOUR_KEY_HERE"
  }}'
```

For Bedrock:
```bash
kubectl patch secret litellm-secrets -n default \
  --type merge \
  -p '{"stringData": {
    "AWS_ACCESS_KEY_ID": "AKIA...",
    "AWS_SECRET_ACCESS_KEY": "...",
    "AWS_REGION_NAME": "us-east-1"
  }}'
```

### Step 2 — Apply the config file

Copy the contents of your chosen config file into the ConfigMap. The simplest way is to replace the `config.yaml` key directly:

```bash
kubectl create configmap litellm-config \
  --from-file=config.yaml=model-config/openrouter-gemini-3.8-flash.yaml \
  --namespace default \
  --dry-run=client -o yaml | kubectl apply -f -
```

Replace `openrouter-gemini-3.8-flash.yaml` with whichever file you want to use.

### Step 3 — Restart LiteLLM

```bash
kubectl rollout restart deployment/litellm-deployment -n default
kubectl rollout status deployment/litellm-deployment -n default --timeout=120s
```

### Step 4 — Verify

Check the pod logs to confirm the model loaded without errors:

```bash
kubectl logs -l app=litellm -n default --tail=50
```

You should see the model name listed in the startup output with no errors.

---

## Two-model configs (Haiku routing)

The `DeepSeek-V4.1-Flash-Haiku.yaml`, `GLM-5.3-Flash-Haiku.yaml`, `GLM-5V-Turbo-Haiku.yaml`, and `Qwen3.8-Max-Haiku.yaml` configs use LiteLLM's `complexity_router` to pair a cheap primary model with Claude Haiku 4.5. Text goes to the primary model; images and PDFs automatically route to Haiku.

These configs require only an `OPENROUTER_API_KEY` — both models run through OpenRouter. Apply them the same way as single-model configs.

---

## Troubleshooting

**"The provided model identifier is invalid"** — The model ID in the config is wrong for the provider. Check the provider's current model ID format.

**"Could not connect to LiteLLM"** — The pod may still be starting. Run `kubectl rollout status` and wait for it to complete.

**Images or PDFs failing** — If using a single-model OpenRouter config, confirm the model supports Anthropic `document` blocks natively (see the matrix). If not, switch to a two-model Haiku config.

**401 Unauthorized** — The API key in `litellm-secrets` is missing or incorrect for the provider. Re-run Step 1 with the correct key.
