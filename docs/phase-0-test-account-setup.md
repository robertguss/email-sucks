# Phase 0 Google connection setup

Status: Read-only OAuth is implemented and locally tested. The selected account's client has been configured, and the local app can offer **Connect Gmail**. Owner consent and a live **Check connection** result are still pending. Interception and sending are unavailable.

## Google project

Use a separate development project with Gmail API enabled. Configure an External Google Auth Platform audience in Testing and add the selected account as a test user. The owner has explicitly authorized the selected account for this read-only slice. Retain direct Gmail access and account recovery independently of this app.

Create a **Web application** OAuth client with this exact local redirect:

```text
http://localhost:4000/auth/google/callback
```

Authorized JavaScript origins are unnecessary for the server-side flow. Use `localhost` when opening the app so the callback returns to the same browser cookie origin. [Google web-server OAuth setup](https://developers.google.com/identity/protocols/oauth2/web-server)

Configure only these scopes for the current slice:

```text
openid
https://www.googleapis.com/auth/userinfo.email
https://www.googleapis.com/auth/gmail.readonly
```

The authorization request uses `email`, Google's OIDC shorthand for the email scope. It validates signed identity, verified email, the configured account allowlist, and the read-only grant. The stored Google subject is pinned on first connection and must match on reconnect. [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)

## Private local files

Keep both files outside the repository, under a directory with mode `0700`; each file must have mode `0600`:

- `~/.config/email-sucks/google-oauth.dev.json`: Google's downloaded web-client JSON.
- `~/.config/email-sucks/keys.dev.json`: JSON containing `allowed_email`, `vault_key`, and `session_secret`. Generate each key independently from 64 random bytes, encoded as URL-safe base64. Never use example strings as keys.

These files have been prepared on the owner's machine. Keep the vault key stable: changing or losing it makes previously stored credentials unreadable. The session key is separate, so signing out or rotating browser sessions does not change credential encryption.

Run `bin/dev-gmail`. It sets `GMAIL_OAUTH_FILE` and `GMAIL_KEYS_FILE` to those paths and starts Phoenix. Environment overrides allow other private paths. `GMAIL_REDIRECT_URI` defaults to the local callback; any override must match a registered redirect. Non-development callbacks must use HTTPS. Startup fails on missing or incomplete configuration without printing its contents.

The native loopback-only development database assumes a trusted local machine. Hosted credentials, database authentication, TLS, and secret-file provisioning must be configured and verified separately before Render deployment. Do not expose this development server or local PostgreSQL port to a network.

## Connection behavior

1. **Connect Gmail** starts a CSRF-protected POST and redirects to Google. OAuth state, nonce, and PKCE verifier are encrypted in a ten-minute server-side flow record; the cookie carries only a random reference.
2. The callback consumes that flow once, validates Google's signature/issuer/audience/expiry/nonce/state, checks the allowed account, encrypts credentials, and creates a revocable eight-hour browser session. Tokens never enter React props or browser storage.
3. **Check connection** reads `users/me/profile`. No message contents or profile counts are stored. Expired access tokens are refreshed under a durable lease; rotated refresh tokens are saved, absent replacements preserve the existing refresh token, and an in-flight refresh cannot overwrite a reconnect.
4. Revoked grants require reconnection. Temporary provider failures keep credentials for a later attempt. **Sign out of this app** invalidates the browser session; it does not revoke Google access. Safe disconnect/revocation is a later recovery feature.

Consumed flow payloads are cleared immediately. Expired flows are removed when another authorization attempt starts; expiry remains enforced even while the app is idle. Authorization starts are capped at ten per minute across this single-user app. There is no background Gmail polling yet.

Google External/Testing refresh tokens can expire after seven days. This is expected in the development project and must be addressed before the later two-week dogfood gate. [Google token expiration](https://developers.google.com/identity/protocols/oauth2#expiration)

## Later scope and deployment gates

Do not add `gmail.modify` or `gmail.settings.basic` until the interception/recovery experiment inventories its exact methods, supplies the offline recovery card, and is authorized. Sending requires its own scope and behavior review. Read-only consent does not authorize those experiments. [Gmail scope reference](https://developers.google.com/workspace/gmail/api/auth/scopes)

Render region, service/database plans, separate hosted Google credentials, and the independent alert destination remain to be selected and verified before provisioning.
