# Bounded existing-filter compatibility proof

Prepared 2026-09-05 after the [live inventory](evidence/phase-0/2026-09-05-filter-compatibility-inventory.md). Status: inspection passed for existing fixtures; arrival-time overlap experiment not run. Automatic interception remains disabled.

## Supported boundary

The current account has three sender-specific Trash filters, with no overlap against the five existing controlled fixtures. Leave those filters intact. Future intake must exclude Spam/Trash/Draft, preserve unrelated labels and read status, and expose conflicts without silently changing user rules. No filter ordering or action precedence is assumed.

An existing user filter that removes Inbox, marks read, forwards, or changes an app-owned label requires separate review and provider evidence before claiming support. A user label alone must survive a controlled hold/release. No such additional actions were observed in this account's three filters.

## Smallest overlap experiment

Use a separate synthetic fixture from `robertguss@gmail.com` to `howtocodeio@gmail.com`, with subject `phase0-filter-trash-001` and harmless text. Do not impersonate the private senders in the existing filters. Do not add this message to the frozen batch or reuse/reset its durable records.

1. Prepare an opt-in, one-fixture interception test with durable ownership of its temporary filter IDs and an independent recovery card. Restrict both test filters to the controlled sender, receiving account, subject phrase and a generated random marker. Verify no pre-existing matching message and retain the original filter snapshot before activation.
2. One temporary filter models the observed user action (`add TRASH`); a second models the proposed app action (`add a dedicated test Held label`, `remove INBOX`). Save each creation intent before its provider call; ambiguous results require read-back and reconciliation. The two filters deliberately overlap only the new synthetic fixture. Do not enable general interception or apply either filter retroactively to old mail.
3. Only after both filter identities and cleanup paths are verified, request one owner-sent fixture. Agent sending requires explicit authorization. Read its exact metadata/labels without opening or marking it read. Record actual Gmail results instead of assuming whether the Held label accompanies Trash.
4. Require Trash to remain present, Inbox absent, and the message excluded from eligible intake. Any app-held label on a trashed message must not turn it into recoverable Inbox mail. Exercise the bounded admission/recovery path under a provider-write guard; require zero attempted message changes and no enrollment into the existing frozen batch. A result that resurrects the message or hides a conflict is a failure.
5. Disable and verify removal of only the two recorded test filters before cleanup. Compare all original filters with the private snapshot. Restore the synthetic message only through an explicit test-cleanup action after observing exclusion, preserving unread/unrelated labels; ordinary recovery must not do this automatically. Verify original batch membership/state and no remaining app interception. Keep the harmless test label if deletion would affect unrelated use.

This tests overlap and Trash exclusion. It does not pass aliases, forwarding, Bcc, threading, device notifications or scheduled delivery.

## Execution prerequisites

The bounded lifecycle is now implemented and locally tested; see the [implementation evidence](evidence/phase-0/2026-09-05-filter-lifecycle.md). Complete review and deployment before requesting activation. Required failure checks include response loss after filter creation, duplicate activation, wrong/stale ownership, partial filter removal, revoked settings access and disconnect while the test is active. Never delete a user filter based only on matching criteria or label names.

The connected app currently has `gmail.modify`; filter creation/deletion requires `gmail.settings.basic`. Broader access needs the owner's Google consent after the implementation and exact activation form are reviewable. Do not request consent merely to inspect filters, and do not work around the missing lifecycle with untracked browser-created filters. [Create authorization](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.filters/create), [delete authorization](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.filters/delete).

Success requires provider evidence for the overlap, zero prohibited recovery writes, unchanged original filters, durable test ownership and verified filter cleanup. A read-only inventory alone cannot pass this gate.
