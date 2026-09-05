# Bounded filter lifecycle implementation

Date: 2026-09-05. Environment: local PostgreSQL, Req provider doubles and Chromium.
Status: implementation reviewed and verified locally; live activation and arrival proof pending.

The opt-in settings flow requests `gmail.settings.basic` in addition to existing
Gmail modification access. Ordinary connection keeps its previous scope. Required
scopes are saved in the encrypted OAuth flow; omitted refresh-response scope
preserves the existing grant metadata, while an explicitly reduced grant wins.

The one-shot experiment uses fixed sender/recipient/subject criteria and a random
marker. It journals intent before filter writes, reconciles uncertain creation by
exact saved specification, rejects ambiguous ownership, and never blindly retries
an unknown creation. Cleanup removes the hold filter before the Trash filter,
verifies absence, snapshots eligible held mail, then reconciles message labels.
Trash, Spam and Drafts remain excluded. A later visible held arrival keeps cleanup
pending and is incorporated on retry without repeating confirmed writes.

Safe disconnect performs filter cleanup before existing single/batch recovery and
revocation. Missing settings permission or incomplete cleanup preserves access and
disconnect intent. Browser recovery requests settings permission only when needed.
No live filters were created by this verification, and no email was sent.

## Verification

- 175 backend tests passed, including an independent committed-database test that
  kills an accepted create request, blocks a competing cleanup request, and
  recovers without duplicate creation.
- 33 browser tests passed, including CSRF-protected activation/recovery/inspection,
  separate scope consent, and disconnect recovery permission forms.
- TypeScript, warnings-as-errors compilation and formatting checks passed.
- Mobile and desktop filter panel screenshots were inspected at 390 and 1440
  pixels; wrapping and action visibility passed.
- Regressions cover lost create/delete responses, uncertain ownership, baseline
  changes, late-visible mail and disconnect interrupted during filter deletion.

Independent review found two defects, reproduced by failing regression tests and
fixed before deployment. Pending-state inspection now refuses the transition
instead of claiming filter drift. Changes to unrelated original filters remain a
durable warning but cannot permanently block safe cleanup after owned filters are
verified absent. Strict ownership checks still block deletion of changed or
ambiguous app filters.

The filter snapshot comparison remains required for the live compatibility proof;
a warning permits recovery but does not pass that experiment. General interception,
filter ordering, device behavior, aliases, Bcc, forwarding and threading have no
new live evidence from this implementation. The synthetic overlap arrival must
wait for owner Google consent and successful tracked activation.

Review receipt: `20260905-091853-29134d0a`, eight local lenses and independent
Claude Opus 5 review; both confirmed findings independently revalidated as fixed,
with no remaining actionable findings. Optional deeper Spam/Draft parameterization
and killed-delete/restore coverage remain follow-up coverage, not live proof.
