# Controlled primary-address filter experiment

Date: 2026-09-04. Status: prepared, not activated. The owner accepts disposable test-message loss and waived the manual export task; this does not authorize broad interception or sending by the agent.

The read-only filter inventory found three rules, each matching a specific unrelated sender and adding Trash. None matches the controlled test sender. This is a bounded inspection, not proof that all future filters or receiving identities are compatible. Criteria and filter IDs remain in the private local inventory outside git.

## Concrete rule

Use the agreed controlled sender and receiving account from the conversation, plus subject phrase `phase0-hold-20260904-k7v2`. Require all three fields. Use a dedicated label `Postman/Phase0-Held-20260904-k7v2` to keep the experiment distinct from product Held mail. Gmail subject matching is a case-insensitive phrase, not exact whole-subject equality.

The private, filled preparation card is at `~/.config/email-sucks/hosted-cougar-cedar/controlled-filter-recovery.md`. Filter/label IDs and rehearsal results are pending actual creation. No credentials are included on the card.

## Sequence and evidence

1. **Rehearse removal without interception:** the owner creates a rule with those criteria and Apply label only, leaving Skip the Inbox unchecked. Do not apply it to existing conversations. Locate the rule in Gmail settings, delete only that rule and verify that the original three remain. No test message is necessary. Record provider IDs/actions and absence after removal through read-only API inspection.
2. **Present the activation result for approval:** the eventual rule adds the dedicated label and removes Inbox. It must not delete, mark read or forward messages, or retroactively act on matching conversations. Interception remains off until the owner authorizes this specific rule after the removal rehearsal. Manual Gmail creation keeps the app's existing grant read-only; it does not prove API filter creation/deletion or remove their later scope requirements.
3. **One synthetic arrival:** owner sends the agreed new fixture. Inspect exact message labels: the dedicated label is present, Inbox absent, and the message remains discoverable directly in Gmail. Record actual results, including Spam/Trash routing or conversation effects; no assumed pass.
4. **Recover:** delete the temporary interception rule FIRST, verify its absence, then restore the synthetic message to Inbox directly in Gmail. Verify actual message-level Inbox presence. Send a second new fixture after removal to check ordinary delivery. No sends are performed by the agent.
5. **Leave interception off:** confirm the original three filters remain, the test filter is absent and no unexpected messages were affected. Capture sanitized results. Broader interception, multi-worker release, device notifications, expired grants, full app outage and API-driven recovery remain separate gates.

The initial hosted smoke checks, profile check and read-only preview have passed. Removal rehearsal and live interception/recovery have not. Do not treat preparation or disposable-message consent as permission to activate the test.

Sources: [Google filter criteria/actions](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.filters), [Gmail create/delete instructions](https://support.google.com/mail/answer/6579?hl=en).
