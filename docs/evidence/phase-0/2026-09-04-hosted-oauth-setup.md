# Hosted read-only OAuth configuration

Date: 2026-09-04. The owner created a separate web OAuth client in the hosted Google project and supplied its downloaded JSON file locally. Verified that it differs from the development client and includes the exact hosted callback. No client secret or key material is recorded here.

Transferred the hosted client over SSH and generated fresh, independent hosted vault/session keys. Private recovery copies remain outside git on the owner's Mac under `~/.config/email-sucks/hosted-cougar-cedar/`. The VM uses a private directory and mode-0400 files owned by the container's unprivileged user. The optional Compose overlay mounts only the two required files, read-only, into the web container. The worker has no Gmail configuration. The existing identity/email and `gmail.readonly` scope requests are unchanged.

Initial production boot with OAuth enabled exposed a Phoenix compile-environment mismatch: runtime set `debug_errors=false`, while the compiled setting was absent. Reproduced the failing release startup. Set `debug_errors=false` explicitly in production compile configuration, rebuilt the Linux release, and verified healthy startup with the actual hosted configuration. No compile-environment validation was disabled. The previous working page was restored during the rebuild.

Verification: Compose validation; successful production compilation/release build; running web reports Gmail configuration present, exact callback/allowed identity matches, and debug errors disabled; worker reports Gmail configuration absent. HTTP readiness returns 200. The Inertia homepage props report `gmail_configured=true` and `gmail_connected=false`. Both credential mounts are read-only. These checks do not call Gmail or complete Google consent.

The first owner sign-in attempt returned Google 403 `access_denied`, stating that access is limited to developer-approved testers. Comparing the downloaded client files confirmed the hosted client belongs to a different project from local development. The hosted project must independently include the approved receiving account in its test-user audience; hosted consent has not passed.

Next: owner adds the receiving account to the hosted project's test users, then refreshes the private app, chooses Connect Gmail, consents with the approved receiving account, then uses Check connection. Hosted sign-in, token refresh and five-message preview remain pending live evidence. Interception and sending remain unavailable.


## Live owner verification and read-only inventory

Subsequent screenshots confirm hosted consent, a successful Check connection, and a five-message metadata preview containing synthetic fixture `phase0-primary-001`, displayed as unread. Other message metadata is deliberately omitted from this record.

The first profile request failed with HTTP 403 despite the token containing `gmail.readonly`. A sanitized direct provider diagnostic returned `accessNotConfigured` / `SERVICE_DISABLED`: Gmail API was disabled in the hosted project. After the owner enabled it and reconnected, the profile check and metadata preview succeeded. The current app incorrectly maps all profile/mail 403 responses to missing scope; correcting that classification remains follow-up work.

The agent then ran the existing read-only provider inventory from the authenticated server environment, using the connected account's encrypted credentials without displaying them. Result: one send-as identity, one matching primary identity, 15 labels, three existing filters, zero Held-filter candidates. The stored profile check timestamp is present. Counts do not prove receiving-alias support or filter compatibility; filter criteria were not requested by this inventory boundary.

Hosted sign-in/profile/preview and the read-only provider inventory have live evidence. Hosted token refresh, interception, recovery, device behavior and independent alerts remain unproven. Next prepare the existing-filter backup and direct Gmail recovery record before proposing any mutation experiment. No additional scopes or mail mutations were performed.
