# Read-only Google connection: local evidence

Date: 2026-09-04

Status: Local implementation and automated checks pass. The owner's private configuration is loaded and the page offers **Connect Gmail**. No real Google consent, token exchange, or Gmail profile check has been completed by this evidence run. No Gmail mutation occurred. Phase 0 exit gates remain open.

## Implemented boundary

- Assent 0.3.1 Google OIDC with native RS256 signature verification, issuer/audience/expiry checks, random nonce, OAuth state, and S256 PKCE. Official Google discovery endpoints were checked on this date and are fixed in the provider adapter.
- Only `openid`, `email`, and `gmail.readonly` are requested. The verified email must match private configuration; the first Google subject is pinned for future reconnects. The application has no mail mutation endpoints.
- Authentication infrastructure uses private Ecto schemas on the existing AshPostgres repository. These are server-only credential/session records, not public Ash actions or the future mail workflow model.
- OAuth flow data and tokens are authenticated-encrypted using Phoenix.Token with a private storage key separate from the cookie secret. Flow consumption is transactionally one-use. SQL logging is disabled for authentication records, and schema inspection redacts sensitive fields.
- The encrypted, HttpOnly, SameSite=Lax cookie contains opaque flow/session references. Browser sessions are hashed in the database, expire after eight hours, rotate on reconnect, and are invalidated on sign-out. Production cookies are Secure.
- POST routes retain Phoenix CSRF protection. Callback responses redirect to a clean URL and use `no-store`/`no-referrer`. Callback parameter logging is disabled, credential-related parameters are globally filtered, detailed development error pages are disabled, and browser log streaming is disabled.
- Refresh work uses a recoverable 30-second database lease and revision checks; Google HTTP requests happen outside transactions, have bounded timeouts, and do not automatically retry or follow redirects. Failed temporary refreshes keep existing credentials. Reconnect cannot be overwritten by an older refresh result.
- Profile checking is an authenticated, explicit action. It reads account identity only and records the time of a successful check, without retaining message contents or profile counts. No background Gmail jobs run.

## Verification

- `mise exec -- mix test`: **43 passed**, including existing snapshot/concurrency/Oban tests.
- Signed OIDC fixtures prove success and rejection of wrong account, unverified email, wrong issuer/audience/nonce, expired identity, invalid signature, wrong state, and missing Gmail scope. The state mismatch test fails if a token exchange is attempted.
- Database tests prove flow expiry/replay rejection, rate limits, ciphertext integrity/context separation, subject pinning, session expiry/logout/rotation, refresh preservation, revoked versus temporary failures, lease exclusion, and refresh-versus-reconnect ordering.
- Controller tests exercise a signed OAuth success through the actual routes, a real CSRF-protected form submission, rejection of missing CSRF, session binding/replay rejection, anonymous access denial, private props, and absence of test credential values in captured logs.
- `mise exec -- mix compile --warnings-as-errors`, `mix format --check-formatted`, TypeScript checking and asset build pass.
- `npm test`: **1 Chromium navigation test passed**, with no page errors or console warnings/errors. Its server explicitly excludes real OAuth configuration.
- A separate Chrome DevTools check of the configured local page shows the **Connect Gmail** button and no console warnings/errors.
- `mix hex.audit`: no retired or security-advisory packages. `npm audit`: zero vulnerabilities reported.
- The development migration applied successfully. Private OAuth/key files are outside the repository with owner-only permissions; their contents are not recorded here.

## Remaining live evidence

The owner must complete Google consent, then run **Check connection**. Actual refresh/revocation/reconnect behavior, Render deployment, operational access controls, alerting, encrypted backups and restore, interception/recovery, and device notification behavior still need real experiments. This local implementation does not pass those gates by inference from mocks.

The native loopback database is a trusted single-user development environment, not proof of hosted database security. Sign-out retains the provider grant; safe disconnect/revocation remains future work. Only one account and one active app session are supported in this proof.

Sources: [Google discovery document](https://accounts.google.com/.well-known/openid-configuration), [Google web-server OAuth](https://developers.google.com/identity/protocols/oauth2/web-server), [Assent Google](https://hexdocs.pm/assent/0.3.1/Assent.Strategy.Google.html), [Assent OIDC](https://hexdocs.pm/assent/0.3.1/Assent.Strategy.OIDC.html), [Phoenix.Token](https://hexdocs.pm/phoenix/1.8.13/Phoenix.Token.html).
