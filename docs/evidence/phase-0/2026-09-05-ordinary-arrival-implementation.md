# Ordinary arrival implementation and review

Date: 2026-09-05. Result: local implementation and verification passed; deployment
and the ordinary arrival provider proof remain pending because the owner's
1Password SSH agent did not complete signing. No ordinary filter was activated.
The prior deployed image remains `6679507`.

The closed `arrival-primary-v1` profile adds one Hold-only filter for its fixed
sender, recipient and synthetic subject plus a fresh marker. It requires the prior
Trash experiment to be disabled and preserves that journal. The authenticated,
CSRF-protected route chooses the profile server-side; client specifications cannot
widen it. The browser hides activation until prior cleanup is complete.

Disconnect now attempts removal of all known profiles' owned filters before
restoring any historical mail. A deleted historical fixture cannot leave newer
interception active. Recovery failures remain durable and prevent revocation;
other eligible profile mail can still be restored. Unknown persisted profiles
block disconnect and produce critical health signals without exposing identifiers.

## Verification

- 198 backend tests and 40 Playwright browser tests passed.
- TypeScript, compilation with warnings as errors, formatting and diff checks passed.
- Independent review `20260905-105445-6dd0a8f9`: seven completed local lenses and
  Claude Opus 5; no failed reviewers. Two corroborated findings were fixed with
  failing-before/passing-after regressions: disconnect ordering and unsupported
  profile health. The missing browser activation-gate check was added and passed.
- Lifecycle regression verifies historical message 404 with an active ordinary
  filter: interception stops first, ordinary restoration succeeds, historical
  error remains, credentials remain available, and repeat cleanup adds zero writes.
- Existing response-loss, ownership-drift, late-arrival, paging and real-database
  durability tests continue to pass. No migration is required for this profile.

These are automated results, not evidence of ordinary Gmail arrival or device
notification behavior. Follow the [bounded plan](../../phase-0-ordinary-arrival.md)
for tracked activation, private recovery-card verification and one owner fixture.
No agent email send is authorized.
