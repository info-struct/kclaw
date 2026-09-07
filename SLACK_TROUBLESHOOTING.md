# Slack Troubleshooting

## Token Mismatch (bot connects but nothing works)

The most common Slack issue after install: the bot connects successfully but either receives no messages, or receives messages but can't reply.

### Symptoms

| Symptom | Cause |
|---------|-------|
| Bot connects, zero events arrive | App token (`xapp-`) is from a different Slack app than the bot token |
| Events arrive, replies fail with `channel_not_found` | Bot token (`xoxb-`) is from a different Slack app than the app token |

Both tokens must come from the **same Slack app**. Easy to get wrong if you have multiple apps in the same workspace.

### How to diagnose

Check which app each token belongs to:

```bash
# App token — returns app_name and app_id
curl -s -H "Authorization: Bearer xapp-1-..." https://slack.com/api/auth.test

# Bot token — returns user (bot display name) and team
curl -s -H "Authorization: Bearer xoxb-..." https://slack.com/api/auth.test
```

If `app_name` from the xapp call doesn't match the bot name from the xoxb call, the tokens are mismatched.

The app ID is also embedded in the xapp token itself — `xapp-1-{APP_ID}-...` — so you can read it directly without an API call.

### Where the tokens live

Tokens are stored in the `kubeclaw-env` Kubernetes secret:

```bash
sudo kubectl get secret kubeclaw-env -n kclaw -o jsonpath='{.data.\.env}' | base64 -d | grep SLACK
```

### How to fix

Get both tokens from the correct Slack app (api.slack.com/apps → your app):

- **Bot Token** (`xoxb-`): OAuth & Permissions → Bot User OAuth Token
- **App Token** (`xapp-`): Basic Information → App-Level Tokens (needs `connections:write` scope)

Then patch the secret and restart:

```bash
# Patch bot token (repeat sed line for SLACK_APP_TOKEN if needed)
CURRENT=$(sudo kubectl get secret kubeclaw-env -n kclaw -o jsonpath='{.data.\.env}' | base64 -d)
NEW=$(echo "$CURRENT" | sed 's|SLACK_BOT_TOKEN=.*|SLACK_BOT_TOKEN=xoxb-...|')
ENCODED=$(echo "$NEW" | base64 -w 0)
sudo kubectl patch secret kubeclaw-env -n kclaw \
  --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/data/.env\", \"value\": \"$ENCODED\"}]"

sudo kubectl rollout restart deployment/kubeclaw-orchestrator -n kclaw
sudo kubectl rollout status deployment/kubeclaw-orchestrator -n kclaw
```

### Verifying it works

After restart, check the orchestrator logs:

```bash
sudo kubectl logs -n kclaw $(sudo kubectl get pods -n kclaw | grep orchestrator | awk '{print $1}') | grep "Slack bot connected"
```

Then send the bot a DM. You should see `Group registered` and `Agent message complete` in the logs within ~30 seconds.

---

## Event Subscriptions Not Configured

If the bot connects but no events arrive even with matching tokens, the Slack app manifest may be missing event subscriptions.

The app manifest must include these under `settings.event_subscriptions.bot_events`:

```json
"bot_events": [
  "message.channels",
  "message.groups",
  "message.im"
]
```

Without these, Slack opens the Socket Mode connection but never pushes message events. Fix in the Slack app dashboard under **Event Subscriptions → Subscribe to bot events**, then reinstall the app to the workspace.
