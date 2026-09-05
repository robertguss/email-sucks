# Gmail recovery card

**General interception preparation copy. The one-fixture app-outage recovery was rehearsed on 2026-09-05; no interception exists in the current prototype.** Before any activation, fill in the private fields below, verify these steps in the actual Gmail interface, and save/print a copy outside the exe.dev VM and this application. Do not store credentials on this card.

## Current controlled prototype: rehearsed steps

The actual label is `Postman/Controlled-primary-001`, not the future `Postman/Held`. Open that label in Gmail, select only the `phase0-primary-001` synthetic fixture checkbox, and choose **Move to → Inbox**. Verify Inbox membership and unread status without opening the message. Gmail retained the controlled label during the rehearsal; its count did not mean mail was still held. After the app returns, use **Release to Inbox** to reconcile the record and remove that residual controlled label. There are no app-owned interception filters to delete in this prototype.

These steps passed with both app processes stopped. See [dated evidence](evidence/phase-0/2026-09-05-independent-recovery.md). A private copy is saved outside the app; the general interception, revoked-access, all-page and new-arrival rehearsals below remain open.

## Private activation record

- Gmail account: ____________________
- Verified date and operator: ____________________
- App-owned filter IDs (API record): ____________________
- Exact filter criteria and actions visible in Gmail: ____________________
- Held label: `Postman/Held` (confirm actual label and ID): ____________________
- Independent alert/support channel: ____________________
- Location of separate recovery-key backup (not the key): ____________________

Gmail filters are identified by their criteria/actions, not an app-assigned display name. Keep an exported copy of the specific app-created filters and distinguish them from unrelated filters.

## If the app is unavailable or access is revoked

1. **Open Gmail directly** at [Gmail](https://mail.google.com/) and verify the account shown. You do not need the email client's sign-in or API credentials.
2. **Stop future interception first.** Open Settings → See all settings → Filters and Blocked Addresses. Match the app-owned filter(s) to the private record above. Delete only those filters and confirm they are gone. If their identity is uncertain, inspect the criteria/actions before deleting anything. Do not revoke app access first; revocation does not remove a Gmail filter. Google's [filter instructions](https://support.google.com/mail/answer/6579) describe locating and deleting filters.
3. **Restore held mail.** Open `Postman/Held`. Select the held mail and use Move to Inbox. If Gmail offers selection of all matching conversations beyond the visible page, include those too. Repeat until every page has been handled. Do not use Delete, Trash or Spam. Do not restore items from Spam/Trash without reviewing them separately.
4. **Verify actual delivery.** Held-label membership alone is not proof of continued holding: Gmail may retain that label after Move to Inbox. Inspect Inbox presence and record any residual exceptions. A message still labeled Held but already in Inbox does not need to be moved again. Gmail's conversation view can group old and new messages; the rehearsal must verify message-level results and document any broader thread effects.
5. **Verify new arrival behavior.** Have the owner send one agreed synthetic fixture from a controlled external account. Confirm it follows ordinary Gmail delivery. Do not assume filter removal guarantees Inbox placement when other user filters or Gmail spam handling apply.
6. **Keep interception off.** Return to the app only after mail is accessible. Report released, still-held and unavailable items. Reconciliation must not hide externally restored messages or automatically reactivate filters. Revoke Google access only after recovery is verified, if disconnecting is still desired.

If a step cannot be completed, keep the account in a visible recovery-blocked state and use the independent support channel. Do not interpret a broken app dashboard or zero displayed count as proof that recovery succeeded.

## Rehearsal record

Use only synthetic test mail. Record the exact Gmail interface/date, filter criteria, message IDs before/after, all-page behavior, Inbox outcomes, new-arrival result and any exceptions in a private evidence record. Commit a sanitized summary with Pass/Fail/Blocked and the application revision. Repeat with the application stopped and with its OAuth grant revoked.

**Activation gate:** this card must be filled in, available offline, and successfully rehearsed before interception is enabled. The [experiment inventory](phase-0-experiment-inventory.md) tracks the remaining account/device prerequisites.
