# Security

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Email: [ryan@info-struct.net](mailto:ryan@info-struct.net)

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fix if you have one

We will acknowledge receipt within 48 hours and aim to release a fix within 14 days for critical issues.

## Credential handling

KClaw is designed so agent pods never have direct access to raw API keys or secrets:

- All credentials are stored encrypted at rest in the CredRouter database
- Agent pods authenticate via short-lived virtual keys issued per-session
- The `install-summary.txt` file generated at install time contains all generated secrets — keep it secure, back it up, and never commit it
- Bedrock credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) and API keys are stored in Kubernetes Secrets and injected via `os.environ/` references in LiteLLM — they are never hardcoded in config files

## Kubernetes security

- Agent pods run as UID 1000 (non-root)
- Team storage volumes are mounted read-only inside agent containers
- Each tenant's workspace is isolated to their own pod and PVC

## Known scope limitations

- The Admin UI uses JWT authentication. Ensure it is not exposed to the public internet without TLS termination and strong credentials.
- SAML SSO exists in CredRouter but has not been fully tested — JIT-provisioned SSO users may be created without a tenant assignment. Do not rely on SSO for access control until this is resolved.
