# OAuth Connection Guide

> Covers the full lifecycle: registering an OAuth provider in the Admin UI, then connecting
> (authorizing) it as a user. Illustrated with **Gmail** and **Microsoft 365** as reference
> examples — the same steps apply to any standard OAuth 2.0 provider (GitHub, Jira, Slack, etc.).

---

## How it works (overview)

```
Provider (Google / Microsoft / …)
        │
        │  1. Admin registers the OAuth app in Admin UI → CredRouter stores
        │     clientId + encrypted clientSecret + scopes + redirect URI
        │
        ▼
  kclaw Admin UI  ←→  CredRouter vault
        │
        │  2. User clicks "Connect <Provider>" → browser redirects to provider
        │     consent screen → provider redirects back to kclaw callback
        │
        ▼
   Callback route exchanges auth code → stores refresh_token in vault
        │
        ▼
   Agent pod starts → CredRouter injects tokens as env vars via envKeyMap
```

No browser access is required inside agent pods after initial setup. The vault mints
short-lived access tokens on demand from the stored refresh token.

---

## Part A — Admin: Register the OAuth App

Done once per provider. Requires admin role in kclaw.

### Step 1 — Create the OAuth app at the provider

**Gmail (Google Cloud)**
1. Sign in to [https://console.cloud.google.com](https://console.cloud.google.com).
2. Create or select a project → **APIs & Services → Library** → enable **Gmail API**.
3. **APIs & Services → OAuth consent screen** → configure app name, support email, and scopes:
   - Add `https://www.googleapis.com/auth/gmail.modify` (or `.readonly` for read-only).
   - User type **External + Testing** is fine initially (add test accounts); **Internal** if your
     Workspace org only. ⚠️ Testing mode refresh tokens expire after 7 days — publish for a
     durable setup.
4. **Credentials → Create credentials → OAuth client ID → Web application**.
   - Under **Authorized redirect URIs** add:
     `https://<YOUR_KCLAW_HOST>/api/auth/oauth/callback/gmail`
5. Download the JSON → copy **Client ID** and **Client Secret**.

**Microsoft 365 (Entra ID)**
1. Sign in to [https://entra.microsoft.com](https://entra.microsoft.com) as Global Admin.
2. **App registrations → New registration** → name the app, select account type
   (`common` for multi-org SaaS; your tenant ID for single-tenant).
3. **Redirect URI → Web** → `https://<YOUR_KCLAW_HOST>/api/auth/oauth/callback/microsoft-365`.
4. From **Overview** copy **Application (client) ID** and **Directory (tenant) ID**.
5. **Certificates & secrets → New client secret** → copy the **Value** immediately.
6. **API permissions → Add a permission → Microsoft Graph → Delegated**:
   `Mail.Read`, `Mail.ReadWrite`, `Mail.Send`, `User.Read` → **Grant admin consent**.
7. ⚠️ If your tenant has **Security Defaults** enabled, OAuth apps will be blocked (error
   `530035`). Disable Security Defaults and replace with Conditional Access policies. See
   `microsoft-oauth-setup.md §9` for the full fix.

**Other providers (GitHub, Jira, Slack, …)**
Register a "Web application" / "OAuth App" in the provider's developer console and set the
redirect URI to `https://<YOUR_KCLAW_HOST>/api/auth/oauth/callback/<slug>`.

---

### Step 2 — Register the provider in kclaw Admin UI

1. Navigate to **Settings → Connections** (admin view).
2. Click **+ Add Provider**.
3. Use a **Quick-fill preset** if available (Gmail, GitHub, Jira, Slack are built in) or fill
   manually:

| Field | Description | Example (Gmail) |
|---|---|---|
| **Name (slug)** | Lowercase identifier — also the URL segment | `gmail` |
| **Display Label** | Shown on the Connect card | `Gmail` |
| **Description** | Optional user-facing hint | `Let your agent read and send email` |
| **Auth URL** | Provider's authorization endpoint | `https://accounts.google.com/o/oauth2/v2/auth` |
| **Token URL** | Provider's token exchange endpoint | `https://oauth2.googleapis.com/token` |
| **Client ID** | From the provider console | `1234….apps.googleusercontent.com` |
| **Client Secret** | From the provider console (write-only after save) | `GOCSPX-…` |
| **Redirect URI** | Must exactly match what's registered at the provider. Click **Compute** to auto-fill from current origin + slug. | `https://kclaw.example.com/api/auth/oauth/callback/gmail` |
| **Scopes** | Space-separated | `https://www.googleapis.com/auth/gmail.modify` |
| **Env Key Map** | Maps token fields → env var names injected into the agent pod. **For Gmail + gog**: map all four keys so `hydration.ts` can configure gogcli inside the pod (see note below). | `refresh_token → GMAIL_REFRESH_TOKEN,GOOGLE_REFRESH_TOKEN`<br>`access_token → GMAIL_ACCESS_TOKEN,GOOGLE_ACCESS_TOKEN`<br>`client_id → GOOGLE_CLIENT_ID`<br>`client_secret → GOOGLE_CLIENT_SECRET` |
| **MCP Server Name** | The `mcp_configs` entry that receives these env vars | `gmail` |
| **Enabled** | Toggle — controls visibility to users | on |

> **Gmail + gog note:** When an agent pod boots, kclaw's `hydration.ts` (`hydrateGoogleCredentials()`)
> reads `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` to configure gogcli headlessly. If either is
> absent, hydration silently skips gog setup and `gog` commands will fail inside the pod. The built-in
> Gmail preset (migration 013) populates all four keys automatically — if you're registering Gmail
> manually, make sure all four are in the envKeyMap as shown above.

4. Click **Add Provider**.

**Microsoft 365 reference values:**

| Field | Value |
|---|---|
| Auth URL | `https://login.microsoftonline.com/common/oauth2/v2.0/authorize` |
| Token URL | `https://login.microsoftonline.com/common/oauth2/v2.0/token` |
| Scopes | `offline_access https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.ReadWrite https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/User.Read` |
| Redirect URI | `https://<YOUR_KCLAW_HOST>/api/auth/oauth/callback/microsoft-365` |

Replace `common` with your tenant ID if single-tenant only.

---

## Part B — User: Connect the Provider

Done once per user. Requires a linked tenant account.

1. In kclaw, go to **My Settings → Connections**.
   - If the tab is absent, no OAuth providers have been registered yet — ask an admin.
2. Find the provider card (e.g. **Gmail** or **Microsoft 365**). Status shows **Not connected**.
3. Click **Connect \<Provider\>**.
   - The browser redirects to the provider's consent screen.
   - Sign in with the account your agent should act as.
   - Approve the requested scopes.
4. The provider redirects back to kclaw. On success the card shows **Connected** and a toast
   confirms the connection.

> If you're redirected back with an error, see the **Gotchas** section below.

**What happens under the hood:**
- Clicking Connect calls `GET /api/auth/oauth/<slug>/init` → kclaw fetches the authorizer
  manifest from CredRouter, generates a random state nonce, signs it into a 10-minute httpOnly
  cookie, and returns the provider authorization URL.
- After consent the provider calls back to `GET /api/auth/oauth/callback/<slug>` → kclaw
  validates the state cookie (CSRF protection), exchanges the authorization code for tokens
  (server-side only — the client secret never reaches the browser), then stores the refresh
  token in the CredRouter vault tagged to your tenant.

---

## Part C — Verify

After connecting, confirm the token flows through:

1. In **My Settings → Connections** the card shows **Connected**.
2. In **My Settings → Active Skills**, the MCP server entry shows **✓ N configured** next to the
   provider's server name. If it shows **⚠ credentials needed**, the envKeyMap or MCP server
   name is misconfigured — ask an admin to edit the provider.
3. Start or restart an agent session. The MCP server should initialize without auth errors.
4. **If using gog:** exec into the agent pod and verify the CLI is wired up:
   ```bash
   gog whoami
   ```
   If this fails, check that `hydration.ts` ran (look for `[hydration]` lines in pod logs) and that
   `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` are present in the pod environment. If gog prompts for
   a keyring passphrase, ensure `GOG_KEYRING_PASSWORD` is set in the pod's environment.

---

## Disconnecting

On the **Connections** card click **Disconnect**. This deletes the harvested token from the
CredRouter vault. The OAuth app registration at the provider is unaffected — you can reconnect
at any time by clicking **Connect** again.

To fully revoke access at the provider as well:
- **Google:** visit [https://myaccount.google.com/permissions](https://myaccount.google.com/permissions) and remove the app.
- **Microsoft:** visit [https://myapps.microsoft.com](https://myapps.microsoft.com) and revoke the app, or an admin can delete the enterprise app in Entra ID.

---

## Gotchas

**No refresh token returned**
The provider only returns a refresh token on the first consent or when re-consent is forced.
If you've previously authorized the same client, the callback will fail with
*"No refresh_token returned by provider."*
- For Google: re-run the Connect flow — kclaw always sends `prompt=consent&access_type=offline`
  which forces re-consent. If the consent screen is skipped, revoke access at
  [https://myaccount.google.com/permissions](https://myaccount.google.com/permissions) first, then reconnect.
- For Microsoft: include `prompt=consent` (kclaw sends this by default) or revoke and reconnect.

**Redirect URI mismatch**
The redirect URI registered in the provider console must match the one in kclaw exactly
(scheme, host, path — no trailing slash). Use the **Compute** button in the provider modal to
get the exact URI, then copy it into the provider console.
- Google error: `redirect_uri_mismatch`
- Microsoft error: `AADSTS50011`

**Google: "Access blocked — app not verified"**
The consenting account is not in the **Test users** list while the app is in **Testing** mode.
Add the account under OAuth consent screen → Test users, or publish the app.

**Google: refresh tokens expire after 7 days**
Apps in **Testing** mode issue refresh tokens that die after 7 days. Fix: publish the app
(Gmail scopes require Google verification) or use a Workspace **Internal** app. The user will
need to reconnect weekly otherwise.

**Microsoft: Security Defaults blocks sign-in (error 530035)**
See `microsoft-oauth-setup.md §9`. Short fix: disable Security Defaults in Entra ID →
Properties and replace with equivalent Conditional Access policies.

**Admin role required, no tenant linked**
Admin accounts without a linked tenant cannot self-serve connect. The Connect button requires
a `tenant_id` in the user session. Have another admin link the account via the Tenants page
first.

**Provider card not shown**
The **Connections** tab is hidden when no providers are registered. Add at least one provider
in **Settings → Connections** (admin view) → **+ Add Provider**.

---

## Quick-reference endpoint table

| Provider | Auth URL | Token URL |
|---|---|---|
| Google | `https://accounts.google.com/o/oauth2/v2/auth` | `https://oauth2.googleapis.com/token` |
| Microsoft 365 | `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/authorize` | `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token` |
| GitHub | `https://github.com/login/oauth/authorize` | `https://github.com/login/oauth/access_token` |
| Jira (Atlassian) | `https://auth.atlassian.com/authorize` | `https://auth.atlassian.com/oauth/token` |
| Slack | `https://slack.com/oauth/v2/authorize` | `https://slack.com/api/oauth.v2.access` |

---

*See also: `gmail-gog-setup.md` (gogcli / `gog` CLI local auth), `microsoft-oauth-setup.md`
(full Microsoft 365 setup reference).*
