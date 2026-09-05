# Primary-address arrival baseline

- Date: 2026-09-04.
- Fixture: `phase0-primary-001`.
- Application revision: `952ac3e`; continuation branch `codex/phase-0-continuation`.
- Environment: owner-operated Gmail; local read-only prototype, no Render deployment.
- Preconditions: owner supplied a controlled external sender and retained direct access to the receiving Gmail account. Account addresses are omitted from this record.
- Action: owner reported sending the agreed synthetic message, then opening the receiving account directly in Gmail.
- Expected result: ordinary Inbox delivery with interception off.
- Observed result: owner answered yes when asked whether the fixture appeared in the Inbox.
- Result: **Pass, owner-reported, for ordinary primary-address delivery only.** The agent did not independently inspect Gmail, provider labels or message IDs.

No interception was activated and no agent send was performed. This observation does not prove interception, release, recovery, device notifications, or hosted behavior. Direct Gmail access was owner-confirmed; the offline recovery card remains unfilled and unrehearsed.

Next action: reconcile the owner's Render deployment deferral with the proof plan's hosted prerequisites before progressing to an interception experiment. Additional scopes and activation remain gated.
