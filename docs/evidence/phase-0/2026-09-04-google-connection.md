# Read-only Google connection: local evidence

Date: 2026-09-04

Status: Local automated checks pass. The owner completed real Google consent and a live Gmail profile check. The authorized live automatic-refresh experiment below also passed. No messages were downloaded or changed. Phase 0 exit gates remain open.

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

## Live automatic-refresh experiment

Completed 2026-09-04 at **21:06:36 UTC** against the owner's authorized account.

1. Confirmed the existing account was connected and its browser session remained valid.
2. Changed only the expiry timestamp inside the encrypted credential payload to a time in the past, advancing the record revision. The actual Google access/refresh tokens and browser session were preserved. This simulates local expiry; it does not revoke access at Google.
3. Clicked **Check connection** in the owner's existing signed-in browser. The production code path claimed the refresh lease, refreshed access with Google, saved encrypted credentials, and read the Gmail profile.
4. Verified the refresh revision advanced exactly once, expiry was again in the future (3,569 seconds remaining at verification), the successful profile-check timestamp advanced, connection status remained connected, and the refresh lease was released.
5. Verified the browser session digest was unchanged. Google did not rotate the refresh token in this exchange; the existing token was retained. No sign-in or consent screen appeared.

The browser displayed **“Gmail connection verified. No messages were downloaded or changed.”** Only status, timing, and boolean comparisons were recorded; no token or account identifier is included in this evidence. The temporary encrypted baseline was removed after successful verification. The application was left with valid refreshed credentials.

This proves automatic refresh triggered by simulated local expiry against the real Google service. It does not prove natural token expiry, provider revocation, refresh-token rotation, or recovery from an actual Google outage.

## Remaining live evidence

Real revocation/reconnect behavior, natural expiry and refresh-token rotation, Render deployment, operational access controls, alerting, encrypted backups and restore, interception/recovery, and device notification behavior still need real experiments. This local implementation does not pass those gates by inference from mocks.

The native loopback database is a trusted single-user development environment, not proof of hosted database security. Sign-out retains the provider grant; safe disconnect/revocation remains future work. Only one account and one active app session are supported in this proof.

Sources: [Google discovery document](https://accounts.google.com/.well-known/openid-configuration), [Google web-server OAuth](https://developers.google.com/identity/protocols/oauth2/web-server), [Assent Google](https://hexdocs.pm/assent/0.3.1/Assent.Strategy.Google.html), [Assent OIDC](https://hexdocs.pm/assent/0.3.1/Assent.Strategy.OIDC.html), [Phoenix.Token](https://hexdocs.pm/phoenix/1.8.13/Phoenix.Token.html).
