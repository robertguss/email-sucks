# Hosted read-only OAuth configuration

Date: 2026-09-04. The owner created a separate web OAuth client in the existing Google project and supplied its downloaded JSON file locally. Verified that it differs from the development client and includes the exact hosted callback. No client secret or key material is recorded here.

Transferred the hosted client over SSH and generated fresh, independent hosted vault/session keys. Private recovery copies remain outside git on the owner's Mac under `~/.config/email-sucks/hosted-cougar-cedar/`. The VM uses a private directory and mode-0400 files owned by the container's unprivileged user. The optional Compose overlay mounts only the two required files, read-only, into the web container. The worker has no Gmail configuration. The existing identity/email and `gmail.readonly` scope requests are unchanged.

Initial production boot with OAuth enabled exposed a Phoenix compile-environment mismatch: runtime set `debug_errors=false`, while the compiled setting was absent. Reproduced the failing release startup. Set `debug_errors=false` explicitly in production compile configuration, rebuilt the Linux release, and verified healthy startup with the actual hosted configuration. No compile-environment validation was disabled. The previous working page was restored during the rebuild.

Verification: Compose validation; successful production compilation/release build; running web reports Gmail configuration present, exact callback/allowed identity matches, and debug errors disabled; worker reports Gmail configuration absent. HTTP readiness returns 200. The Inertia homepage props report `gmail_configured=true` and `gmail_connected=false`. Both credential mounts are read-only. These checks do not call Gmail or complete Google consent.

Next: owner refreshes the private app, chooses Connect Gmail, consents with the approved receiving account, then uses Check connection. Hosted sign-in, token refresh and five-message preview remain pending live evidence. Interception and sending remain unavailable.
