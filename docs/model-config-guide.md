# Model Config Guide

KClaw uses LiteLLM as a model proxy. This guide covers how to switch models for both install methods:

- **[Helm chart](#helm-chart)** — update `values.yaml` and run `helm upgrade`
- **[k3s installer](#k3s-installer)** — apply a config file from `model-config/` manually

---

## Picking a config

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

See [model-support-matrix.md](model-support-matrix.md) for a full comparison.

---

## Two-model configs (Haiku routing)

The `DeepSeek-V4.1-Flash-Haiku.yaml`, `GLM-5.3-Flash-Haiku.yaml`, `GLM-5V-Turbo-Haiku.yaml`, and `Qwen3.8-Max-Haiku.yaml` configs use LiteLLM's `complexity_router` to pair a cheap primary model with Claude Haiku 4.5. Text goes to the primary model; images and PDFs automatically route to Haiku.

These configs require only an `OPENROUTER_API_KEY` — both models run through OpenRouter.

---

## Helm chart

Model and provider are set in your `values.yaml` (or override file). Run `helm upgrade` to apply — the chart re-renders the `litellm-config` ConfigMap and rolls the LiteLLM pod automatically.

### Switching provider or model

Edit your values file:

```yaml
llm:
  provider: openrouter      # anthropic | bedrock | openrouter

  anthropic:
    apiKey: "sk-ant-..."

  bedrock:
    accessKeyId: "AKIA..."
    secretAccessKey: "..."
    region: us-east-1

  openrouter:
    apiKey: "sk-or-v1-..."
    model: "google/gemini-3.8-flash"   # any OpenRouter model ID
```

Then upgrade:

```bash
helm upgrade kclaw kclaw/kclaw \
  --namespace kclaw \
  -f my-values.yaml
```

The chart generates a LiteLLM config equivalent to the `model-config/` files for the chosen provider. If you need a specific two-model routing config (e.g. `DeepSeek-V4.1-Flash-Haiku`), use the [k3s installer method](#k3s-installer) below to apply it manually after the helm install.

### Verify

```bash
kubectl rollout status deployment/litellm -n kclaw --timeout=120s
kubectl logs -n kclaw -l app=litellm --tail=20
```

---

## k3s installer

LiteLLM reads its config from a Kubernetes ConfigMap (`litellm-config`) and credentials from a Secret (`litellm-secrets`), both in the `default` namespace.

### Step 1 — Update the Secret (if switching providers)

**OpenRouter:**
```bash
kubectl patch secret litellm-secrets -n default \
  --type merge \
  -p '{"stringData": {"OPENROUTER_API_KEY": "sk-or-YOUR_KEY_HERE"}}'
```

**Bedrock:**
```bash
kubectl patch secret litellm-secrets -n default \
  --type merge \
  -p '{"stringData": {
    "AWS_ACCESS_KEY_ID": "AKIA...",
    "AWS_SECRET_ACCESS_KEY": "...",
    "AWS_REGION_NAME": "us-east-1"
  }}'
```

`LITELLM_MASTER_KEY` and `DATABASE_URL` are always required and are set during initial install — you do not need to change them when switching models.

### Step 2 — Apply the config file

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

```bash
kubectl logs -l app=litellm -n default --tail=50
```

You should see the model name listed in the startup output with no errors.

---

## Troubleshooting

**"The provided model identifier is invalid"** — The model ID in the config is wrong for the provider. Check the provider's current model ID format.

**"Could not connect to LiteLLM"** — The pod may still be starting. Run `kubectl rollout status` and wait for it to complete.

**Images or PDFs failing** — If using a single-model OpenRouter config, confirm the model supports Anthropic `document` blocks natively (see the matrix). If not, switch to a two-model Haiku config.

**401 Unauthorized** — The API key is missing or incorrect for the provider. Re-run Step 1 with the correct key.
