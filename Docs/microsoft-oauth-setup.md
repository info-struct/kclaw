# Microsoft 365 OAuth Gateway — Setup Guide (TEMPLATE)

> **Generic template.** Replace everything in `<ANGLE_BRACKETS>` with your values.
> Nothing tenant-specific is baked in. "Smart defaults" are pre-filled — override only if you
> have a reason to.

Goal: **one** multi-tenant app owned by you/your org. Users click **"Connect Microsoft 365"**
and consent once. Your backend (the token vault) holds the refresh tokens; worker pods/services
get short-lived access tokens.

---

## 0. Fill-in-the-blanks (with smart defaults)

| Placeholder | Default | Notes |
|---|---|---|
| `<APP_NAME>` | `Mail Gateway` | Shown on the consent screen — make it recognizable. |
| `<TENANT>` | `common` | `common` = any work/school **+** personal accounts (SaaS). Use `organizations` for work/school only, or `<TENANT_ID>` for single-tenant. |
| `<TENANT_ID>` | *(from Overview)* | Directory (tenant) GUID. Needed if you use single-tenant. |
| `<CLIENT_ID>` | *(from Overview)* | Application (client) ID. |
| `<CLIENT_SECRET>` | *(create it)* | Secret **Value** — only for the confidential-client flow. Never ship to clients. |
| `<REDIRECT_URI>` | `https://<YOUR_HOST>/oauth/microsoft/callback` | Must be **HTTPS**, exact match, no trailing slash. |
| `<YOUR_HOST>` | e.g. `auth.example.com` | The host running the OAuth callback (the gateway, not per-user workers). |
| `<MAILBOX>` | *(the user's UPN)* | e.g. `user@example.com`. |
| `<SCOPES>` | see §3 | Default set below covers read/write/send mail. |

**Smart defaults, summarized:**
- Account type → **multi-tenant** (`common`) if serving many orgs; **single-tenant** if just yours.
- Secret expiry → **24 months**, with a rotation reminder.
- Flow → **device code** for headless/testing; **authorization code** for the real web gateway.
- Token lifetime → access ~**1h**, refresh **long-lived**; store only the refresh token.

---

## 1. Register the app (once, as tenant admin)

1. Sign in to **https://entra.microsoft.com** as a **Global Admin**.
2. **Entra ID → App registrations → New registration**
   - **Name:** `<APP_NAME>`
   - **Supported account types:**
     - Multi-org SaaS → *Accounts in any organizational directory and personal Microsoft accounts*
     - Your org only → *Accounts in this organizational directory only*
   - **Redirect URI:** platform **Web** → `<REDIRECT_URI>` (HTTPS, exact, no trailing slash)
   - **Register**
3. From **Overview**, copy **Application (client) ID** → `<CLIENT_ID>` and **Directory (tenant) ID** → `<TENANT_ID>`.

> **Tip — resolve the tenant ID from a domain** (no portal needed):
> ```bash
> curl -s "https://login.microsoftonline.com/<yourdomain.com>/v2.0/.well-known/openid-configuration" \
>   | python3 -c "import json,sys;print(json.load(sys.stdin)['issuer'])"
> # the GUID in the issuer is the tenant ID
> ```

## 2. Client secret (confidential-client flow only)

**Certificates & secrets → Client secrets → New client secret** → copy the **Value** → `<CLIENT_SECRET>`.
- *Skip this if you only need the device-code flow* (public client, no secret).

## 3. API permissions + admin consent

**API permissions → Add a permission → Microsoft Graph → Delegated permissions:**
- `Mail.Read`, `Mail.ReadWrite`, `Mail.Send`, `User.Read`
- (`offline_access`, `openid`, `profile`, `email` are OIDC scopes — requested at login; don't add them here)

Then **Grant admin consent** → all show green. (`<SCOPES>` for the request =
`offline_access https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.ReadWrite https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/User.Read`.)

## 4. The five values

| Item | Value |
|---|---|
| **Auth URL** | `https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/authorize` |
| **Token URL** | `https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/token` |
| **Client ID** | `<CLIENT_ID>` |
| **Client Secret** | `<CLIENT_SECRET>` |
| **Redirect URI** | `<REDIRECT_URI>` |

`<TENANT>` = `common` · `organizations` · `<TENANT_ID>`.

**Other endpoints:**
- Device code: `https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/devicecode`
- Admin consent: `https://login.microsoftonline.com/<TENANT>/adminconsent?client_id=<CLIENT_ID>&redirect_uri=<REDIRECT_URI>`
- Logout: `https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/logout`
- Discovery: `https://login.microsoftonline.com/<TENANT>/v2.0/.well-known/openid-configuration`
- JWKS: `https://login.microsoftonline.com/<TENANT>/discovery/v2.0/keys`

---

## 5. Flow — authorization code (web gateway)

**a) Send the user to authorize:**
```
GET https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/authorize
  ?client_id=<CLIENT_ID>
  &response_type=code
  &redirect_uri=<REDIRECT_URI>
  &response_mode=query
  &scope=<SCOPES>
  &state=<random-csrf-token>
  &prompt=consent
```

**b) Exchange code → tokens (backend):**
```
POST https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/token
Content-Type: application/x-www-form-urlencoded

client_id=<CLIENT_ID>&client_secret=<CLIENT_SECRET>&grant_type=authorization_code
&code=<code>&redirect_uri=<REDIRECT_URI>&scope=<SCOPES>
```
→ `access_token` (~1h), `refresh_token`, `expires_in`, `id_token`.

**c) Refresh on demand:**
```
POST https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/token
client_id=<CLIENT_ID>&client_secret=<CLIENT_SECRET>&grant_type=refresh_token
&refresh_token=<stored>&scope=<SCOPES>
```

**d) Call Graph:**
```
GET https://graph.microsoft.com/v1.0/me/messages?$top=10
Authorization: Bearer <access_token>
```

## 6. Flow — device code (headless / no browser) ⭐

**1. Request a code:**
```bash
curl -s -X POST "https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/devicecode" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "client_id=<CLIENT_ID>" \
  --data-urlencode "scope=<SCOPES>"
# → user_code, device_code, verification_uri=https://login.microsoft.com/device, expires_in=900
```
**2. User** opens `https://login.microsoft.com/device`, enters `user_code`, signs in.
**3. Poll** until tokens land:
```bash
curl -s -X POST "https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
  --data-urlencode "client_id=<CLIENT_ID>" \
  --data-urlencode "device_code=<device_code>"
# pending → {"error":"authorization_pending"}; success → access_token + refresh_token
```
No `client_secret` needed. **Requires:** *Authentication → "Allow public client flows" = Yes*.

## 7. Storage model (token vault)

- Store **per user**: `refresh_token`, `tenant`, `upn`, `scopes`, `created_at`. Encrypt at rest.
- Pods/services request mail actions from the vault → it returns a **short-lived access token**
  (or proxies the Graph call). Pods never hold refresh tokens.
- Rotate the client secret before expiry; keep it in a secret manager, never in code.

---

## 8. Gotchas

- **Redirect URI must match exactly** (scheme/host/path, no trailing slash) → else `AADSTS50011`.
- **Never leave `<TENANT>`/`{tenant}` literal** in a URL → `AADSTS900023`. Use the GUID or domain.
- **Admin consent is required** for org accounts once (per tenant).
- **Client secret is confidential** — vault-side only.
- **App passwords are being retired** by Microsoft — don't rely on IMAP basic auth.
- **Publisher verification** may be required at scale (100+ installs, mail scopes).
- **Global Admins bypass "Assignment required?"** — so that toggle won't block *you*, but it
  will block regular users if left On.

---

## 9. ⚠️ The #1 silent blocker: **Security Defaults** (error `530035`)

**Symptom:** sign-in appears to succeed, then:

> *"You don't have access to this. Your sign-in was successful but you don't have permission to
> access this resource."* — **Error Code: 530035**

Happens for **any** app (including Microsoft first-party), so it's **tenant-wide**, not your app.

**Diagnose (don't guess):** Entra ID → **Monitoring & health → Sign-in logs** → filter
**Status = Failure** → open the entry (search by the **Correlation ID** from the error page).
The **Failure reason** is authoritative — for this issue it reads
**"Access has been blocked by security defaults."**

**Root cause:** **Security Defaults** (Entra ID → Properties → *Manage Security Defaults*) is an
all-or-nothing baseline with **no per-app exceptions**. While on, it blocks custom-app OAuth
sign-in.

**Fix:** **Security Defaults and Conditional Access are mutually exclusive** — you don't run
both. Correct end state = **Security Defaults OFF, Conditional Access ON**, replicating the
protections below. Allow **a few minutes** for propagation before retrying.

**Conditional Access policies to replicate Security Defaults** (create in **Report-only** first):
1. **Require MFA for all users** — All users + All cloud apps → *Require multifactor authentication*
2. **Require MFA for admins** — Directory roles (privileged) → *Require MFA*
3. **Block legacy authentication** — Conditions → Client apps = **"Other clients"** → *Block*
4. *(optional)* Require MFA for Azure management

> 🚨 **Exclude a break-glass admin account from every policy** or a bad policy locks you out.

**No Entra ID P1?** (CA needs P1 — included in Business Premium / E3/E5, **not** Basic/Standard.)
Use **per-user MFA** as a compensating control: *Entra → Users → \<user\> → Authentication
methods* (or legacy per-user MFA in the M365 admin center). Enforces MFA without P1.

---

## 10. Setup checklist

**A. App registration**
- [ ] New registration — name `<APP_NAME>`, account type per §0
- [ ] Redirect URI `<REDIRECT_URI>` (HTTPS, exact)
- [ ] Copy **Client ID** + **Tenant ID**
- [ ] Create client secret (if using confidential flow) — copy the **Value**
- [ ] API permissions: `Mail.Read`, `Mail.ReadWrite`, `Mail.Send`, `User.Read` → **Grant admin consent**
- [ ] *(device code)* Authentication → **Allow public client flows = Yes**

**B. Tenant toggles that silently block**
- [ ] **Security Defaults** — see §9 ⚠️
- [ ] **Conditional Access** — no policy blocking the app / requiring unmeetable conditions
- [ ] **User consent settings** — allow admin consent (users can't self-consent if disabled)
- [ ] **"Assignment required?"** (enterprise app) — set **No** for a shared gateway
- [ ] **"Enabled for users to sign-in?"** (enterprise app Properties) — must be **Yes**

**C. Optional**
- [ ] Optional claim → ID → `email` (some tenants omit it)
- [ ] Branding & properties (publisher, logo, ToS/privacy) for a legit consent screen
- [ ] Publisher verification (Partner Center) at scale

**D. Multi-tenant**
- [ ] Send each customer's admin the admin-consent URL:
      `https://login.microsoftonline.com/<TENANT>/adminconsent?client_id=<CLIENT_ID>&redirect_uri=<REDIRECT_URI>`

---

*Template — no tenant-specific values. Fill the placeholders in §0 and go.*
