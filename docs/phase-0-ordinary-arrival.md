# Bounded ordinary-arrival proof

Status: reviewed implementation deployed at `75f7f0e`; one bounded filter is
active and verified, awaiting the owner fixture. All 198 backend and 40 browser
tests pass. [Activation evidence](evidence/phase-0/2026-09-05-ordinary-arrival-activation.md).
This is the next Phase0 experiment, not general interception or scheduled intake.

## Fixed boundary

Use a new immutable experiment ID, `arrival-primary-v1`, in the existing ownership
table. Preserve the completed `primary` Trash-overlap row, nonce, IDs and outcomes.
The new profile may activate only after that prior experiment is disabled and no
other experiment remains unresolved.

Exactly one filter holds future mail from `robertguss@gmail.com` to the configured
controlled receiving account, with subject phrase `phase0-filter-arrival-001` and
a fresh generated marker. Its only actions are adding a dedicated test label and
removing Inbox. It must not add Trash or match arbitrary client-supplied criteria.
No fixture is sent until activation and private offline recovery details are
verified. Agent sending still needs explicit authorization.

## Implementation and verification

1. Extend the existing durable lifecycle with closed profile definitions; retain
   ambiguous-create reconciliation, strict ownership, no blind retries, baseline
   warning preservation, removal before restoration and late-arrival recovery.
   Verify independent rows, unknown-profile refusal and exact one-filter behavior.
2. Add a distinct authenticated, CSRF-protected form/route that chooses the fixed
   profile on the server. Preserve existing Trash-test behavior. Verify spoofed
   profile parameters cannot widen the boundary; show marker/instructions only
   after verified activation.
3. Disconnect and operational health cover every saved experiment, including the
   new row when the old row is disabled. Verify neither can ignore unfinished
   ordinary-filter recovery or erase previous evidence.
4. Run existing and new backend/browser checks, independent review, deploy, and
   verify initial not_started state alongside the preserved disabled prior row.
5. Activate through the tracked lifecycle, request one owner-sent fixture, read
   exact metadata/labels, require unread + held label + absent Inbox, then disable
   interception and restore eligible mail to Inbox with unread/unrelated labels
   preserved. Repeat cleanup and verify no duplicate message writes.

## Limits

Visible To and exact subject validation remain strict for this profile. It does
not silently claim Bcc, arbitrary aliases, forwarding or mixed-thread support.
Later fixed profiles can test those independently. The released ordinary message
can become a mixed-thread seed only after the basic provider proof passes; actual
threadId comparison will be required. Existing batch membership remains separate.
