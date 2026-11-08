# Gmail via `gog` — Setup Guide (TEMPLATE)

> ⚠️ **This guide is for local workstation setup only** (IT administrators and business users
> configuring their own machine).
> **Web application** client and stores tokens in the CredRouter vault. Mixing the two will
> cause `redirect_uri_mismatch` errors because Desktop clients reject HTTPS redirect URIs.

> **Generic template.** Replace everything in `<ANGLE_BRACKETS>` with your values.
> Nothing account-specific is baked in. "Smart defaults" are pre-filled — override only if you
> have a reason to.
>
> Companion to the *Microsoft 365 OAuth Gateway — Setup Guide*. Same idea, Google side: one
> OAuth client you own, one-time consent, and `gog` (gogcli) stores the refresh token locally so
> commands can hit Gmail/Calendar/Drive without a browser.

Goal: **one** Google Cloud OAuth client owned by you/your org. You authorize **once** with
`gog auth add`, `gog` stores the refresh token in a local keyring, and every later `gog gmail …`
call mints a short-lived access token automatically. No IMAP, no app passwords, no browser on
the pod after setup.

---

## 0. Fill-in-the-blanks (with smart defaults)

| Placeholder | Default | Notes |
|---|---|---|
| `<GCP_PROJECT>` | e.g. `kclaw-gateway` | Google Cloud project that owns the OAuth client + enabled APIs. |
| `<APP_NAME>` | `Mail Gateway` | Shown on the Google consent screen — make it recognizable. |
| `<OAUTH_CLIENT_NAME>` | `gog-<APP_NAME>` | The `gog` **client name** (`--client`). Selects which stored credential + token bucket to use. Lets you juggle multiple Google clients. |
| `<CREDENTIALS_JSON>` | `~/client_secret_<id>.json` | The file you **download** from Google (contains `client_id` + `client_secret`). |
| `<ACCOUNT_EMAIL>` | `<user@gmail.com>` | The mailbox to authorize (`gog auth add <email>`). |
| `<DOMAIN>` | *(optional)* | Map a domain → this client so `gog` auto-picks it (e.g. `example.com`). |
| `<SCOPES>` | see §3 | Default = Gmail modify + settings. |
| `<KEYRING>` | `auto` | `auto` \| `keychain` \| `file`. Headless/CI must use `file` + `GOG_KEYRING_PASSWORD`. |

**Smart defaults, summarized:**
- Client type → **Desktop app** for the local/loopback flow (`gog` runs a temporary
  `http://127.0.0.1:<PORT>/oauth2/callback` listener). **Web application** only if you need a
  fixed HTTPS redirect on a gateway.
- Consent status → **Testing** is fine to start (≤100 test users) but **refresh tokens die after
  7 days** (see §10 ⚠️). **Publish** for a durable token (Gmail scopes need *verification*).
- Scope → **full** (`gmail.modify`) for read/write/send; **`--readonly`** for read-only agents.
- Keyring → **`auto`** on a workstation; **`file`** + `GOG_KEYRING_PASSWORD` on a headless pod.
- Token lifetime → access ~**1h** (auto-refreshed by `gog`); refresh **long-lived** (subject to
  §10). Only the refresh token is stored.

---

## 1. Create the Google Cloud project + enable the Gmail API

1. Sign in to **https://console.cloud.google.com** with the Google account that will **own** the
   app (ideally a Workspace/org account, not a personal one).
2. **Project picker → New Project** → name it `<GCP_PROJECT>` → **Create** → select it.
3. **APIs & Services → Library** → search **Gmail API** → **Enable**.
   - *Optional:* enable **Google Calendar API**, **Drive API**, etc. — but only what you need.
   - ⚠️ Skipping this gives `Gmail API has not been used in project <N> before or it is disabled`
     on first call (see §10).

> **Tip — set the project once from the CLI** so you don't fat-finger it in the console:
> `gcloud config set project <GCP_PROJECT>` (if `gcloud` is installed).

## 2. Configure the OAuth consent screen

**APIs & Services → OAuth consent screen** (newer console: **Google Auth Platform → Branding /
Audience / Clients**).

1. **User type:**
   - **External** — any Google account (consumer `@gmail.com` included). Starts in **Testing**.
   - **Internal** — only accounts in *your* Workspace org (`<DOMAIN>`); no verification needed.
2. **App information:** app name `<APP_NAME>`, your support email, developer contact.
3. **Scopes** — add the Gmail scopes (see §3).
4. **Test users** (External + Testing only): add `<ACCOUNT_EMAIL>` and any other accounts that
   will authorize. A non-test user hitting the consent screen gets **"Access blocked: app not
   verified"** (see §10).
5. **Publishing status:** leave **Testing** while iterating; **Publish** when ready for durable
   tokens.

## 3. Scopes

Handled for you by `gog`'s service sets, but here's the mapping so you can register the right
ones on the consent screen:

| `gog auth add` option | Requested Gmail scope(s) |
|---|---|
| `--services gmail --gmail-scope full` *(default)* | `https://www.googleapis.com/auth/gmail.modify` (read + compose + send + label changes) |
| `--services gmail --gmail-scope readonly` | `https://www.googleapis.com/auth/gmail.readonly` |
| *(full set always adds)* | `.../gmail.settings.basic`, `.../gmail.settings.sharing` |
| *(OIDC, always)* | `openid`, `email`, `profile` |

- `--readonly` (top-level) downgrades **every** service to its read-only scope where available.
- Register the same URIs on the consent screen so the requested set is a subset of what's approved.
- **Gmail scopes are classified "restricted/sensitive"** → public publishing requires Google
  **verification** + a security assessment. **Test users are exempt**, which is why Testing mode
  is the pragmatic default for an internal agent.

## 4. The values / endpoints

| Item | Value |
|---|---|
| **Auth URL** | `https://accounts.google.com/o/oauth2/v2/auth` |
| **Token URL** | `https://oauth2.googleapis.com/token` |
| **Device-code URL** | `https://oauth2.googleapis.com/device/code` |
| **Revoke URL** | `https://oauth2.googleapis.com/revoke` |
| **OIDC discovery** | `https://accounts.google.com/.well-known/openid-configuration` |
| **Client ID** | `<CLIENT_ID>` *(from the downloaded credentials.json)* |
| **Client secret** | `<CLIENT_SECRET>` *(same file — Desktop clients are "public" but still ship one)* |
| **Loopback redirect** | `http://127.0.0.1:<PORT>/oauth2/callback` *(Desktop-app flow; `gog` picks the port)* |
| **Web redirect** | `https://<YOUR_HOST>/oauth2/callback` *(Web-app flow only)* |

> Google does **not** allow arbitrary redirect URIs. Desktop clients are limited to the
> **loopback** `http://127.0.0.1:<PORT>` (and `http://localhost`). Web clients must list each
> redirect URI **exactly** (scheme/host/path) in the console → else `redirect_uri_mismatch`.

---

## 5. Create the OAuth client + download credentials

**APIs & Services → Credentials → Create credentials → OAuth client ID.**

- **Application type:**
  - **Desktop app** → for the normal `gog auth add` local browser flow (§6). ← default
  - **Web application** → if you need a fixed HTTPS redirect (a gateway/remote flow, §7).
    - **Authorized redirect URIs:** add `https://<YOUR_HOST>/oauth2/callback` **and**
      `http://127.0.0.1:<PORT>/oauth2/callback` if you also want the local flow.
- **Create** → **Download JSON** → save as `<CREDENTIALS_JSON>`.
  - The file is a Google client-secret JSON with an **`installed`** (Desktop) or **`web`** (Web)
    block holding `client_id` + `client_secret`. `gog` accepts either; a malformed file errors
    with *"invalid credentials.json (expected installed/web client_id and client_secret)"*.

## 6. Store the client credentials + authorize the account (`gog`)

**a) Store the OAuth client** (once per client):

```bash
gog auth credentials set <CREDENTIALS_JSON> --client <OAUTH_CLIENT_NAME> [--domain <DOMAIN>]
# stdin works too:
cat <CREDENTIALS_JSON> | gog auth credentials set - --client <OAUTH_CLIENT_NAME>
gog auth credentials list           # verify it's stored
```

**b) Authorize the mailbox** (opens a browser — do this on a machine with a browser):

```bash
gog auth add <ACCOUNT_EMAIL> \
  --client <OAUTH_CLIENT_NAME> \
  --services gmail \
  --gmail-scope full            # or: --readonly
```

- A browser opens the Google consent screen; approve → `gog` catches the loopback redirect and
  **stores the refresh token in the keyring**.
- Add `--force-consent` if Google skips the consent screen and you don't get a refresh token
  (*"no refresh token received; try again with --force-consent"*).
- Authorize more services by comma-listing them: `--services gmail,calendar,drive`.

## 7. Headless / no-browser flows (pods, CI, remote)

Google's device-code flow is **not** what `gog` uses for this; instead `gog` supports two
browserless authorization-code variants that hand you a URL and let you paste the result back.

**Option A — `--manual` (paste the redirect URL):**
```bash
gog auth add <ACCOUNT_EMAIL> --client <OAUTH_CLIENT_NAME> --services gmail --manual
# 1. gog prints an auth URL → open it in ANY browser, approve
# 2. browser lands on http://127.0.0.1:<PORT>/oauth2/callback?... (may fail to load — that's fine)
# 3. copy the FULL redirect URL from the address bar and paste it back into gog
```

**Option B — `--remote --step 1|2` (split across machines):**
```bash
# Step 1 (on the pod): print the URL
gog auth add <ACCOUNT_EMAIL> --client <OAUTH_CLIENT_NAME> --services gmail --remote --step 1
# ...approve in a browser on your laptop, copy the redirect URL...
# Step 2 (on the pod): exchange it
gog auth add <ACCOUNT_EMAIL> --client <OAUTH_CLIENT_NAME> --services gmail \
  --remote --step 2 --auth-url "<PASTED_REDIRECT_URL>"
```

Useful knobs for either flow:
- `--redirect-uri <URI>` — override the redirect (must match a registered one).
- `--redirect-host <HOST>` — build the callback as `https://<HOST>/oauth2/callback`.
- `--listen-addr <IP[:PORT]>` — bind the callback listener (e.g. `0.0.0.0:8080`).
- `--timeout <DURATION>` — manual flows default to **5m**.

**Keyring for headless hosts** (no OS keychain):

```bash
gog auth keyring file                       # switch backend to file
export GOG_KEYRING_PASSWORD='<STRONG_PASSPHRASE>'   # required; keep it in your secret store
gog auth add <ACCOUNT_EMAIL> --client <OAUTH_CLIENT_NAME> --services gmail --no-input
```

> The file backend encrypts the refresh token with `GOG_KEYRING_PASSWORD`. If it changes you get
> *"file keyring password mismatch or corrupted entry"* → re-run `gog auth doctor --check`.

## 8. Verify

```bash
gog auth status                       # config path, config_exists, keyring_backend
gog auth list                         # accounts with stored tokens
gog auth credentials list             # stored OAuth clients
gog auth doctor --check               # health-check keyring + token plumbing
gog whoami                            # identity of the active account (if wired)

# live Gmail read (the real test)
gog gmail search 'newer_than:1d' --max 5 -j
gog gmail messages list --max 5 -p    # TSV
```

## 9. Storage & secrets model

- **What's stored where:**
  - **OAuth client** (`client_id` + `client_secret`) → `gog auth credentials` store
    (under `<CONFIG_DIR>/gogcli/`).
  - **Refresh token** → the **keyring** backend (`keychain`, or encrypted `file`).
  - **Config** → `<CONFIG_DIR>/gogcli/config.json` (e.g. `/home/node/.config/gogcli/config.json`;
    honors `XDG_CONFIG_HOME`).
- **The client secret is confidential-ish** — for Desktop clients Google treats it as non-secret,
  but still keep the JSON out of repos and pods' plaintext. Prefer a secret manager.
- **Agents never need browser access after setup** — they read the refresh token from the keyring
  and mint ~1h access tokens on demand. Optionally hand a pod a short-lived access token directly
  via `--access-token` / `$GOG_ACCESS_TOKEN` (bypasses the keyring entirely).
- **Lock agents down:** `--readonly` (read-only scopes), `--gmail-no-send` (block sends),
  `--disable-commands` / `--enable-commands` (dot-path allow/deny lists), `--no-input`
  (never prompt — fail instead; good for CI).
- **Rotate:** revoke with the **Revoke URL** (`https://oauth2.googleapis.com/revoke?token=…`) or
  `gog auth remove <ACCOUNT_EMAIL>`, then re-authorize. Delete an OAuth client in the console if a
  secret leaks.

---

## 10. Gotchas

- **⚠️ Testing mode → refresh tokens expire every 7 days.** The #1 silent blocker. In **Testing**,
  Google issues refresh tokens that **die after 7 days**, so a working setup "mysteriously" stops
  after a week. Fix: **Publish** the app (Gmail scopes then need verification — see §3), or keep a
  Workspace **Internal** app, or re-authorize weekly. Diagnose by re-running `gog auth add … --force-consent`.
- **"Access blocked: <APP_NAME> has not completed the Google verification process"** (or
  **"app not verified"**) → you're signing in as a user who is **not a test user** while in
  Testing, or the app is External + unpublished with restricted scopes. Add the account as a
  **Test user**, or publish + verify.
- **"Gmail API has not been used in project … or it is disabled"** → enable the API in the right
  `<GCP_PROJECT>` (§1). Easy to enable it in a *different* project than the OAuth client lives in.
- **`redirect_uri_mismatch`** → the redirect you're using isn't registered **exactly**. Desktop
  clients must use **`http://127.0.0.1:<PORT>/oauth2/callback`** (or `http://localhost`); Web clients
  must list the exact HTTPS URI.
- **No refresh token** → Google only returns one on first consent (or with `prompt=consent`). Re-run
  with **`--force-consent`**.
- **`invalid credentials.json (expected installed/web client_id and client_secret)`** → you stored
  the wrong file (e.g. a service-account key or the OIDC discovery doc). Use the **OAuth client**
  download.
- **Keyring fails headless** → no OS keychain on a pod. `gog auth keyring file` + set
  **`GOG_KEYRING_PASSWORD`**, then re-run `gog auth doctor --check`.
- **`--client` matters** → credentials and tokens are bucketed per client name. If a command can't
  find a token, you're likely on the wrong `--client` (or pass `-a <email>`).
- **Workspace admins** can block third-party OAuth apps org-wide (**Admin console → Security →
  API controls → App access control**). If Internal auth fails for everyone, check there.
- **Anti-pattern to avoid:** don't script raw Google OAuth by hand when `gog auth` already handles
  loopback capture, refresh, and keyring storage.

---

## 11. Setup checklist

**A. Google Cloud**
- [ ] Create/select project `<GCP_PROJECT>`
- [ ] **Enable Gmail API** (Library) — and any other APIs you need
- [ ] OAuth consent screen — user type **External** (Testing) or **Internal**; app name `<APP_NAME>`
- [ ] Add Gmail scopes (§3) to the consent screen
- [ ] Add **Test users** (External + Testing): `<ACCOUNT_EMAIL>` + any others
- [ ] **Credentials → Create OAuth client ID** — **Desktop app** (default) → **Download JSON** → `<CREDENTIALS_JSON>`

**B. `gog` client + account**
- [ ] `gog auth credentials set <CREDENTIALS_JSON> --client <OAUTH_CLIENT_NAME>` → `gog auth credentials list` shows it
- [ ] `gog auth keyring <auto|keychain|file>` (use **file** + `GOG_KEYRING_PASSWORD` on headless hosts)
- [ ] `gog auth add <ACCOUNT_EMAIL> --client <OAUTH_CLIENT_NAME> --services gmail --gmail-scope full` *(or `--readonly`; `--manual`/`--remote` if no browser)*
- [ ] `gog auth list` shows the account

**C. Verify**
- [ ] `gog auth status` — `config_exists=true`, expected `keyring_backend`
- [ ] `gog auth doctor --check` — clean
- [ ] `gog gmail search 'newer_than:1d' --max 5` returns mail

**D. Harden (agents)**
- [ ] Grant **read-only** scope if possible (`--readonly`)
- [ ] `--gmail-no-send` and/or `--disable-commands` to block risky ops
- [ ] `--no-input` in non-interactive contexts
- [ ] Store `GOG_KEYRING_PASSWORD` + any client JSON in a **secret manager**, never in code/repos
- [ ] **Publish** the app (or accept weekly re-auth) so refresh tokens don't expire at 7 days ⚠️

---

*Template — no account-specific values. Fill the placeholders in §0 and go. Companion to
`microsoft-oauth-setup-TEMPLATE.md`; `gog` is gogcli v0.16.0.*
