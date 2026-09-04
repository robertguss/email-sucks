# Deliberate Email Client
## Product Specification and Phased Implementation Plan

**Working title:** TBD  
**Internal component names:** “the postman” for controlled delivery; “the room” for the email experience  
**Document status:** Proposed implementation baseline  
**Version:** 1.0  
**Date:** September 4, 2026  
**Initial scope:** Web application, Gmail only, one user and one Gmail account  
**Supersedes:** The earlier “Email Client — Product Spec & MVP” draft  
**Audience:** Product, design, engineering, quality assurance, and implementation agents  

> This document intentionally does **not** select a programming language, framework, database, hosting provider, job system, notification provider, deployment model, or system architecture. Those decisions belong in a separate technology and architecture document.

---

# 1. Purpose

This document defines the product behavior, implementation scope, state semantics, requirements, milestones, acceptance criteria, risks, validation work, and release gates for a deliberate email client built around two ideas:

1. **The postman** controls when ordinary email is delivered.
2. **The room** provides a bounded place to process that delivery to a real finish line.

This is not a feature inventory for a conventional inbox. It is the implementation contract for a behavioral product experiment: determine whether scheduled delivery, deterministic routing, explicit commitments, and a constrained interface can make email feel finite and subordinate to the user.

The implementation must preserve that thesis while remaining safe enough to use with a real Gmail account. No visual polish or behavioral benefit justifies silently losing, trapping, misdelivering, or duplicating email.

---

# 2. Product Thesis

Email became a taskmaster because arrival became continuous, every message was presented as equally urgent, and the inbox became an unbounded list with no natural stopping point.

This product restores a postman-like rhythm:

- Ordinary mail arrives into a held state.
- Mail is released only at times selected by the user.
- Each release is a finite batch.
- The user deliberately enters the room, processes that batch, and reaches a visible completion state.
- Open obligations remain organized by commitment horizon rather than disappearing through snooze.
- Gmail remains available as a fallback and recovery surface.

The intended emotional outcome is not “faster email.” It is:

- fewer involuntary checks,
- fewer interruptions,
- clearer distinctions between action and awareness,
- fewer invisible open loops,
- a smaller perceived workload,
- confidence that leaving the app does not mean neglecting an endlessly growing inbox.

---

# 3. Product Outcomes

## 3.1 Primary outcomes

The MVP must determine whether the product can:

1. Reduce unscheduled email checking.
2. Make each delivery feel bounded and finishable.
3. Separate action-required mail from awareness mail with a deterministic, understandable system.
4. Keep open obligations visible without turning them into an urgent queue.
5. Track conversations in which the user is waiting for a response.
6. Let the user complete most ordinary email work without returning to Gmail.
7. Fail safely when account access, scheduling, interception, or release behavior breaks.

## 3.2 Safety outcomes

The MVP is not successful unless all of the following remain true:

- No message is silently deleted, sent to spam, or made unrecoverable by the app.
- No outgoing message is sent twice.
- No held message is silently skipped by a delivery run.
- No message that arrives after a release snapshot is accidentally swept into that release.
- A broken app cannot indefinitely trap future incoming email without a visible recovery path.
- The user can disable interception and restore held mail without relying on the normal delivery workflow.
- A failed send leaves the draft intact and does not change the work item’s state.
- Every automatic classification can be explained and corrected.

## 3.3 Product hypotheses

The first dogfood release will test these hypotheses:

- One scheduled delivery per day is tolerable for normal mail when explicit exceptions and emergency access exist.
- Most mail can be routed using user rules and deterministic message signals.
- A one-message-at-a-time awareness flow is calmer than a conventional message list.
- Defaulting action items to **This Week** reduces false urgency.
- “Caught up” can be meaningful when defined as clearing new intake rather than resolving every open commitment.
- The user can rely on the app for ordinary reading, replying, searching, and attachment handling often enough to avoid habitual fallback to Gmail.

---

# 4. Product Principles

## 4.1 User control

- The app must never autonomously send or delete email.
- Every automatic route must be explainable.
- Every classification and workflow decision must be correctable.
- The guided session is optional; each primary place remains directly accessible.
- “Check now,” emergency peek, panic release, and safe disconnect remain available even though they are deliberately de-emphasized.

## 4.2 Deterministic first

- MVP routing uses explicit user rules and deterministic message metadata.
- No model decides whether a message is action-required.
- Future AI may suggest classifications, summaries, or drafts, but cannot silently route, send, delete, or resolve.

## 4.3 Finite intake

- Each delivery is a frozen batch.
- Mail that arrives during a session waits for the next delivery unless explicitly bypassed.
- The active intake must not grow while it is being processed.
- “Caught up” means every released item has been reviewed, classified, or committed—not that every obligation is finished.

## 4.4 Default to non-urgent

- New action items default to **This Week**.
- Users promote items to **Today** rather than demoting everything from an urgent default.
- Waiting is a workflow status, not a due-date bucket.
- Snooze is not part of the MVP.

## 4.5 Few places and few verbs

- The product has five primary places: Doorstep, Pile, Desk, Page, and Drawer.
- A shared Letter reading surface and utility overlays do not count as additional places.
- The Desk is the only persistent workload list.
- Search results, rules, and utility views may use lists when necessary, but they must not resemble a conventional always-visible mailbox sidebar.

## 4.6 Craft without gamification

- Completion is explicit and satisfying.
- Motion communicates state changes only.
- No points, streaks, badges, leaderboards, or performance scores.
- Metrics used during dogfood are diagnostic and mostly invisible during normal use.

## 4.7 Gmail remains recoverable

- Original mail remains in Gmail.
- The app must preserve a direct path to open the original conversation in Gmail.
- App-owned Gmail labels must be namespaced, inspectable, and documented.
- The user must be able to recover held mail directly in Gmail if the app is unavailable.

---

# 5. Scope

## 5.1 MVP scope

The MVP includes:

- One Gmail account.
- One user.
- Web application.
- Desktop-first use with responsive access to critical recovery functions on a phone.
- Scheduled delivery windows.
- Deliberate manual release through Check Now.
- Explicit bypass rules for time-sensitive senders or mailing identities.
- Emergency read-only access to held mail.
- Deterministic classification into Needs You, Aware, or Unsure.
- User-created rules at conversation, sender, mailing-list, and domain scope.
- Explainable routing.
- Finite delivery batches.
- Doorstep, Pile, Desk, Page, Drawer, Letter, and Caught Up experiences.
- Horizons: Today, This Week, Whenever.
- Waiting status with elapsed time and reply reactivation.
- New compose, Reply, and Reply All.
- Draft recovery.
- Basic file attachments for reading, downloading, and sending.
- Safe HTML rendering and plain-text fallback.
- Gmail-backed search presented as conversation results.
- Settings, rules, health, recovery, export, and disconnect utilities.
- Synchronization of new mail, outgoing mail, thread changes, and relevant external Gmail activity.
- Instrumentation for a two-week dogfood experiment.

## 5.2 Explicitly out of scope for MVP

The MVP does not include:

- Multiple Gmail accounts.
- Multiple users, teams, or shared inboxes.
- Outlook, IMAP, or other providers.
- Native desktop or mobile applications.
- Billing, subscriptions, public onboarding, or account administration.
- AI routing, summarization, drafting, or natural-language rules.
- General-purpose newsletter extraction or article-style reader mode.
- Bundles.
- Time-based snooze or future resurfacing.
- Person-centric workspace.
- Contact notes.
- Attachment library.
- Rich document editor.
- Custom subject renaming for existing conversations.
- In-app spam reporting.
- In-app permanent deletion.
- In-app forwarding.
- Calendar RSVP workflows.
- Inline image composition.
- Send-later scheduling.
- Undo Send.
- Full parity with Gmail search, settings, filters, categories, or mailbox management.

When an excluded capability is necessary, the user must have a clear **Open in Gmail** escape hatch. Use of that escape hatch must be measurable during dogfood.

---

# 6. Terminology

| Term | Definition |
|---|---|
| **Message** | One received or sent email. |
| **Conversation** | Gmail’s thread grouping of related messages. |
| **Work item** | The app’s current action state for a conversation. A conversation has at most one current work item. |
| **Delivery window** | A user-configured local time at which held mail is eligible for release. |
| **Delivery batch** | A frozen set of exact held message identifiers selected by one scheduled or manual release. |
| **Batch item** | The representation of one conversation within a delivery batch, including its new messages and review state. |
| **Held mail** | Incoming mail intentionally kept out of ordinary delivery until a release window. |
| **Bypass mail** | Mail allowed to arrive immediately because of an explicit user rule. |
| **Classification** | Needs You, Aware, or Unsure. |
| **Review state** | Whether the user has processed a batch item from a specific delivery. |
| **Work status** | Open, Waiting, or Resolved. |
| **Horizon** | Today, This Week, or Whenever. Applies only to Open work items. |
| **Keep** | A saved-awareness flag. It does not mean unread or unresolved. |
| **Routing rule** | A deterministic rule that assigns a delivery policy or classification. |
| **System heuristic** | A deterministic built-in rule based on message metadata. |
| **Correction** | A user decision that changes a classification or workflow state. It may apply only to one conversation or create a persistent rule. |
| **Caught Up** | The state in which no released batch item remains unreviewed, even if open or waiting work remains on the Desk. |
| **Emergency peek** | A deliberate read-only view of held mail without releasing the batch. |
| **Panic release** | A recovery action that first stops future interception and then restores currently held mail to ordinary Gmail delivery. |

---

# 7. Product State Model

The implementation must not treat one label or one status field as the entire workflow. These dimensions are independent.

## 7.1 Delivery policy

Each incoming message has one delivery policy:

- **Hold** — ordinary behavior; wait for the next delivery batch.
- **Bypass** — immediate behavior defined only by an explicit user rule.

System heuristics may not create bypass rules. Bypass is always an affirmative user choice.

## 7.2 Delivery state

A held message progresses through:

- **Held**
- **Released**

A bypassed message has:

- **Bypassed**

A message cannot be both Held and Released. A bypassed message is not included in a scheduled delivery batch.

## 7.3 Classification

A conversation’s effective classification is exactly one of:

### Needs You

The conversation currently requires a reply, decision, or external action from the user.

### Aware

The newly delivered content is informational and does not currently require action. Aware mail may still be replied to; “Aware” means “no action currently required,” not “reply forbidden.”

### Unsure

The system cannot confidently apply Needs You or Aware under the deterministic rule set. Unsure is a temporary intake state that requires the user to classify it.

## 7.4 Review state

Review state belongs to a **batch item**, not permanently to the conversation:

- **Unreviewed**
- **Reviewed**

This distinction is necessary because the same conversation can appear in multiple delivery batches over time.

Examples:

- An open This Week conversation can receive a new reply and become unreviewed again.
- An Aware conversation reviewed last week can reappear with a new Aware message today.
- A Waiting conversation can receive a reply and re-enter intake without losing its history.

## 7.5 Work status

A work item has one of these statuses:

- **Open** — the user currently owes an action.
- **Waiting** — the user has acted and expects an external response.
- **Resolved** — no current obligation remains.

## 7.6 Horizons

Only an Open work item has a horizon:

- **Today**
- **This Week**
- **Whenever**

Waiting is not a horizon. Resolved work has no horizon.

### Today semantics

- Today is anchored to the user’s local calendar date.
- An unresolved Today item becomes Overdue after the local day ends.
- It does not silently move to a later horizon.

### This Week semantics

- This Week is anchored to the Friday ending the commitment week in the user’s local timezone.
- An item assigned Saturday or Sunday is assigned to the following Friday.
- An unresolved item remains Overdue after that Friday.
- It does not silently roll into a new week.
- Monday presentation may frame the section as the week’s plan rather than a backlog.

### Whenever semantics

- Whenever has no due date.
- It remains visible on the Desk.
- It does not block Caught Up after its associated delivery item has been reviewed.

## 7.7 Keep flag

- Keep applies to an Aware conversation.
- Keep marks the conversation for intentional future retrieval.
- Keep does not leave the item in the active Pile.
- Kept conversations are available through a saved view in the Drawer.
- The flag can be removed.

## 7.8 Invariants

The product must enforce these invariants:

1. A message cannot be both Held and Released.
2. A conversation has one effective classification.
3. A work item has one work status.
4. An Open work item has exactly one horizon.
5. Waiting and Resolved work items have no active horizon.
6. A conversation can be in many historical delivery batches but has at most one current work item.
7. Replaying a completed release or transition cannot create duplicate state changes.
8. Automatic routing cannot demote an existing Needs You item to Aware.
9. A new external human reply to a Waiting conversation reactivates it as Needs You.
10. Aware review never deletes or hides the underlying Gmail conversation.
11. Gmail read/unread state is not the app’s workflow state.
12. Gmail archive state is not equivalent to Done.
13. App-owned Gmail labels are a fallback projection, not user commands when edited externally.
14. Caught Up depends on review completion, not the absence of open work.
15. A failed send cannot change Open, Waiting, or Resolved status.
16. A message that arrives after a release snapshot remains held for a later batch.

---

# 8. Resolved Product Decisions

The following former ambiguities are resolved for MVP:

| Question | MVP decision |
|---|---|
| Should Aware mail be placed in Gmail Inbox at release? | No. Aware remains outside Inbox and is available through the Pile, Drawer, app-owned labels, and Open in Gmail. |
| Should Cc-only mail automatically become Aware? | No. This is not a default hard rule. A disabled-by-default optional heuristic may be exposed later in settings. |
| What does Later mean in the Pile? | The action is renamed **Skip**. It moves the current item to the back of the active Pile without persistent deferral. |
| Where does Keep live? | In a saved Keep view inside the Drawer. |
| Does Waiting silently close when a reply arrives? | No. It reactivates as Needs You and becomes unreviewed in the next delivery. |
| What does Caught Up mean? | All released intake is reviewed or committed. Open and Waiting items may remain on the Desk. |
| Which routing rules win? | Explicit user rules always win over built-in heuristics. |
| Does a correction always create a permanent sender rule? | No. “Just this conversation” is the default. Persistent sender, list, or domain rules require an explicit choice. |
| Is Contacts integration required? | No. It is excluded from MVP. |
| Is “previously corresponded with” retained? | Yes. It means the user has previously sent mail to the normalized sender address from the connected Gmail account. |
| Is reader-mode extraction in MVP? | No. MVP uses safe plain text or sanitized HTML with an original-message escape hatch. |
| Are attachments supported? | Reading, downloading, and basic sending are included. Inline composition and an attachment library are deferred. |
| Is Gmail’s native notification assumed to produce one batch alert? | No. The product requires one batch notification, but the delivery mechanism is an architecture decision and must be validated. |
| Does the app manage delete and spam? | No. Those actions remain in Gmail during MVP. |
| Does the app support forward? | No. Use Open in Gmail and measure fallback usage. |
| Is Undo Send included? | No. Failed sends preserve drafts; successful sends are final. |
| Is there one default delivery window? | Yes. Onboarding starts with one user-selected daily window. Additional windows are opt-in. |

---

# 9. Core User Journeys

## 9.1 First-run onboarding

The onboarding flow must:

1. Explain scheduled delivery in plain language.
2. Explain that ordinary incoming mail will be held outside Gmail Inbox.
3. Explain bypass rules, Check Now, emergency peek, panic release, and direct Gmail recovery.
4. Connect exactly one allowed Gmail account.
5. Discover and display the account’s primary address and known send-as identities.
6. Allow the user to add any other receiving identities that must be covered.
7. Ask the user to choose a timezone and one initial daily delivery window.
8. Create or verify app-owned Gmail labels.
9. Validate interception using a controlled test message.
10. Validate release using a controlled test batch.
11. Confirm that the user can locate held mail directly in Gmail.
12. Present printable or copyable manual recovery instructions.
13. Enable interception only after all safety checks pass.
14. Show a final health summary before entering the Doorstep.

Onboarding must not leave a partially configured interception rule active after failure.

## 9.2 Normal held arrival

For an ordinary message:

1. The message is intercepted.
2. It remains available in Gmail under the app-owned Held label.
3. It does not enter the active room.
4. It is eligible for the next scheduled or manual release.
5. It cannot change the counts of a batch already being processed.

## 9.3 Explicit bypass arrival

For a message matching an explicit bypass rule:

1. It follows ordinary immediate Gmail delivery.
2. It is not included in a held delivery batch.
3. It may still create or update an app work item after synchronization.
4. The bypass is visibly attributable to the rule that caused it.
5. The user can disable or narrow the rule.
6. Bypass usage is measured because frequent bypasses may invalidate the product thesis.

## 9.4 Scheduled delivery

At a delivery window:

1. The system selects an exact frozen set of held message identifiers.
2. Messages arriving after the snapshot remain held.
3. Every selected message is routed deterministically.
4. Messages are grouped into distinct conversations.
5. Each conversation receives an effective classification.
6. The delivery batch records the route and reason for each item.
7. Held state is removed only from the exact messages in the snapshot.
8. Needs You and Unsure conversations enter the attention path.
9. Aware conversations enter the Pile without entering Gmail Inbox.
10. The Doorstep presents stable counts for the batch.
11. One batch notification is sent if the batch is non-empty and notifications are enabled.
12. A partial failure remains visible and retriable; the system must not report the batch complete prematurely.

## 9.5 Check Now

Check Now:

- Performs a normal release using the same rules, safety behavior, and batch semantics as a scheduled delivery.
- Creates a manual delivery batch.
- Is visually deliberate rather than styled as refresh.
- Is logged for dogfood analysis.
- Cannot run concurrently with another release.
- Does not bypass routing.
- Is different from emergency peek.

## 9.6 Emergency peek

Emergency peek:

- Shows held mail without releasing it.
- Is read-only except for Open in Gmail.
- Is available from a utility or recovery surface, not the normal Doorstep flow.
- Records its use.
- Does not mark a held item reviewed.
- Does not change future batch membership.
- Exists for authentication codes, fraud alerts, same-day changes, or similar exceptions before a bypass rule is created.

## 9.7 Guided session

A guided session proceeds:

1. Doorstep
2. Pile
3. Desk
4. Caught Up

The user may jump directly to any place at any time. The room must never trap the user in a wizard.

If a new delivery occurs while an older batch remains unfinished:

- The Doorstep reports the new batch and the earlier remainder separately.
- The session processes unreviewed items oldest first unless the user changes the order.
- Caught Up appears only after all released intake is reviewed.

## 9.8 Aware triage

For an Aware item in the Pile:

- **Next** marks the current batch item reviewed and advances.
- **Keep** marks it reviewed, adds Keep, and advances.
- **Skip** moves it to the back of the active Pile without marking it reviewed.
- **Promote** changes the conversation to Needs You, creates or updates an Open work item with default horizon This Week, marks the batch item reviewed, and advances.
- **Reply** remains available through the Letter surface even though it is not a primary Pile verb.
- **Correct route** may apply only to the conversation or create a persistent rule.
- **Open in Gmail** remains available.

If every remaining item has only been skipped, the app must state that intake remains. It must not show Caught Up.

## 9.9 Needs You triage

A newly released Needs You conversation:

- Is an Open work item.
- Defaults to This Week.
- Appears as unreviewed intake on the Desk until the user acknowledges or acts on it.
- May be moved to Today or Whenever.
- May be replied to.
- May be marked Done.
- May be moved to Waiting only after an outgoing message or explicit user action.
- Is removed from Gmail Inbox after it is acknowledged, committed to a horizon, replied to, or resolved.
- Remains visible on the Desk according to its horizon or Waiting status.

Acknowledgment must be explicit. Merely opening and closing a Letter does not count as review.

## 9.10 Unsure triage

An Unsure conversation appears above the Desk’s horizon groups.

The user must choose:

- Needs You
- Aware

After the choice:

- The current batch item is marked reviewed.
- Choosing Needs You creates an Open work item with default horizon This Week.
- Choosing Aware resolves the intake item and may optionally add Keep.
- The default correction scope is Just This Conversation.
- Persistent options include exact sender, mailing list identity when present, or domain.
- The user sees the proposed match scope before saving a persistent rule.
- The user can undo the classification change.

## 9.11 Reply and send disposition

After a successful reply or new outgoing message associated with a work item, the app asks for one disposition:

- **Done**
- **Waiting**
- **Keep Open**

No workflow state changes before the send succeeds.

For a new standalone message:

- The message is sent without automatically creating a work item.
- The user may choose “Expect a reply” after sending, which creates Waiting.

## 9.12 Waiting and reply arrival

When an Open item becomes Waiting:

- Its horizon is cleared.
- Waiting start time is recorded.
- The Desk displays elapsed calendar time.
- The underlying conversation remains searchable and openable.

When a new external human reply arrives:

- The Waiting state is cleared.
- The conversation becomes Needs You and Open.
- It defaults to This Week unless an existing stronger user decision applies.
- The new reply becomes an unreviewed batch item in the next scheduled or manual delivery.
- The product may display a quiet “Name replied” message during that delivery.

Obvious automated responses, bounces, and delivery-status notifications must not silently close Waiting. They are routed as Aware or Unsure according to deterministic rules.

## 9.13 Work performed in Gmail

Gmail remains a fallback, so the app must reconcile relevant external actions.

- External read/unread changes do not resolve app work.
- External archive changes do not mean Done.
- External edits to app-owned labels do not act as workflow commands.
- An externally sent reply associated with an Open work item creates a visible disposition prompt: Done, Waiting, or Keep Open.
- An external incoming reply to Waiting follows the normal reactivation flow.
- If a conversation becomes unavailable because it was deleted, trashed, or otherwise inaccessible, the app shows an exception rather than silently resolving it.
- The user must be able to open the current Gmail source whenever available.

## 9.14 Panic release

Panic release must:

1. Stop or disable future interception first.
2. Identify all currently held mail.
3. Restore held mail to ordinary Gmail Inbox delivery.
4. Preserve a detailed result showing released, failed, and still-held counts.
5. Be safe to run more than once.
6. Remain available even when normal scheduling or routing is unhealthy.
7. Provide direct Gmail recovery instructions if app-driven recovery fails.

## 9.15 Safe disconnect

Disconnect must:

1. Pause all scheduled and manual releases.
2. Disable future interception.
3. Restore all held mail.
4. Verify that no mail remains trapped.
5. Offer export of rules, windows, and workflow metadata.
6. Explain what happens to app-owned Gmail labels.
7. Revoke account access only after recovery succeeds or the user explicitly accepts a documented residual risk.
8. Never revoke access first and leave an active intercept rule behind.

---

# 10. Delivery and Batch Requirements

## 10.1 Delivery windows

The user can configure:

- One or more local delivery times.
- Enabled days of the week.
- Timezone.
- Notification preference.

MVP onboarding begins with one daily window.

Requirements:

- Daylight-saving changes must preserve the user’s intended local clock time.
- A missed window must result in a visible catch-up decision rather than silent abandonment.
- The next delivery time must always be displayed as an exact local date and time when ambiguity exists.
- Changing timezone must show how upcoming windows will move before saving.
- Duplicate or overlapping windows must be prevented.
- Check Now must not change the configured schedule.

## 10.2 Frozen batches

Each release must create a durable conceptual batch with:

- release type: scheduled or manual,
- scheduled time,
- actual start and completion time,
- exact message identifiers,
- grouped conversation identifiers,
- route result,
- route explanation,
- per-item review state,
- release errors,
- completion status.

The implementation must support safe retry after interruption.

## 10.3 Counts

Delivery counts use **distinct conversations**, not raw messages.

The Doorstep and notification may show:

- N need you
- N to look over
- N need sorting, when Unsure is non-zero

A conversation containing several new messages counts once. The Letter highlights every newly released message in that conversation.

If older intake remains:

> Mail’s here: 3 need you, 14 to look over. 2 from earlier remain.

Counts remain stable for the batch. They do not change when additional mail arrives into Held state.

## 10.4 Conversation aggregation

When multiple messages in one released conversation receive different message-level results, effective conversation precedence is:

1. Needs You
2. Unsure
3. Aware

Additional rules:

- A current Needs You work item cannot be automatically demoted by an Aware message.
- A reply to Waiting becomes Needs You regardless of lower-priority bulk signals unless it is confidently an automated response.
- An explicit conversation-level user decision outranks automatic aggregation.
- A new message in a Resolved conversation may create a new work item.
- A new Aware message may not erase an existing Open obligation.

---

# 11. Deterministic Routing Specification

## 11.1 Delivery-policy routing

Delivery policy is evaluated at arrival.

Order:

1. Explicit conversation bypass rule.
2. Explicit exact-sender bypass rule.
3. Explicit mailing-list bypass rule.
4. Explicit domain bypass rule.
5. Hold.

No built-in heuristic may bypass scheduled delivery.

## 11.2 Classification routing

Classification is evaluated at release. First match wins.

### User-controlled rules

1. Explicit conversation override.
2. Exact sender rule.
3. Mailing-list identity rule.
4. Domain rule.

A user rule may assign Needs You or Aware. Rules display their scope, outcome, creation source, and last match.

### Built-in Aware heuristics

5. Recognized bulk or list headers.
6. Recognized mailing-list identity.
7. Common automated sender local-part patterns such as no-reply, notifications, newsletter, mailer, or alerts.
8. Gmail category signals for Promotions, Social, Updates, or Forums.

### Built-in Needs You heuristic

9. The user has previously sent mail to the exact normalized sender address.

### Optional disabled heuristic

10. “Not directly addressed to a known user identity” may route to Aware only when the user explicitly enables it. It is off by default.

### Fallback

11. Everything else becomes Unsure.

Contacts are not used in MVP.

## 11.3 Rule explanations

Every route must show:

- final classification,
- winning rule,
- relevant matched value,
- whether the rule was user-created or built in.

Examples:

- “Aware — matched mailing-list header.”
- “Needs You — you previously wrote to this address.”
- “Aware — your exact-sender rule.”
- “Unsure — no rule matched.”

Explanations must not expose raw unsafe header content without sanitization.

## 11.4 Corrections

Every classified conversation can be corrected.

Correction scopes:

1. Just this conversation — default.
2. Always this exact sender.
3. Always this mailing list, when a reliable list identity exists.
4. Always this domain — advanced and clearly warned as broad.

Requirements:

- The UI previews the rule’s scope.
- Domain rules require an explicit confirmation.
- Persistent rules can be viewed, searched, edited, disabled, and deleted.
- Rule conflicts are surfaced.
- User rules always precede built-in heuristics.
- Deleting a rule does not retroactively rewrite historical classifications.
- A correction affects the active work item immediately.
- Undo restores the prior state and removes a newly created rule when applicable.

---

# 12. Gmail Fallback and Recovery Behavior

The product must keep Gmail understandable as a fallback.

## 12.1 App-owned labels

MVP uses namespaced labels that are recognizable in Gmail:

- `Postman/Held`
- `Postman/Review`
- `Postman/NeedsYou`
- `Postman/Aware`
- `Postman/Unsure`
- `Postman/Horizon/Today`
- `Postman/Horizon/Week`
- `Postman/Horizon/Whenever`
- `Postman/Waiting`
- `Postman/Keep`

The exact technical representation is an architecture decision, but the user-visible semantics are fixed.

## 12.2 Inbox behavior

- Held mail stays outside Gmail Inbox.
- Released Aware mail remains outside Gmail Inbox.
- Released Needs You and Unsure mail may enter Gmail Inbox while unreviewed, providing fallback visibility.
- Once acknowledged, classified, committed to a horizon, replied to, or resolved, it is removed from Gmail Inbox.
- Open work remains available on the app Desk and under app-owned Gmail labels.
- The app never equates Gmail Inbox presence with the authoritative workflow state.
- The app never deletes, trashes, or marks spam in MVP.

## 12.3 Read/unread behavior

The product must make an explicit implementation choice during feasibility validation:

- either held mail remains unread in Gmail without creating unacceptable badge behavior,
- or held mail is marked read and the app preserves independent unreviewed state.

The choice must be based on actual device testing. The app’s review state never depends on Gmail unread state.

## 12.4 Manual recovery instructions

The product must make these instructions available outside normal workflow:

1. Open Gmail.
2. Open the `Postman/Held` label.
3. Select all held mail.
4. Move it to Inbox.
5. Disable or delete the app-owned interception filter.
6. Return to the app only after ordinary delivery is restored.

The exact Gmail steps must be verified against the user’s actual Gmail interface before dogfood begins.

---

# 13. Notification Requirements

## 13.1 Batch notification

The product requires at most one app-controlled notification for a non-empty delivery batch.

Example:

> Mail’s here. 3 need you, 14 to look over, 2 need sorting.

Requirements:

- No per-message app notifications.
- No notification for an empty batch.
- A manual Check Now may suppress the batch alert when the user is already in the app.
- Notification counts must match the frozen batch.
- Tapping the notification opens the Doorstep for that batch.
- Notification failure must not block release.
- The Doorstep remains the authoritative presentation of delivery state.

## 13.2 Gmail notifications

The product must not assume that Gmail will:

- suppress every held-mail notification,
- emit a notification when Inbox is added later,
- group a batch into exactly one notification,
- use the app’s custom wording.

Actual Gmail and phone behavior must be validated in Phase 0. If the user enables bypass rules, bypassed messages may follow normal Gmail notification behavior as an explicit exception.

## 13.3 Health alerts

Critical health alerts must not rely solely on the intercepted Gmail account.

Examples:

- interception active but releases failing,
- account authorization lost,
- oldest held mail exceeds the grace period,
- app-owned filter missing or altered,
- partial panic release.

The notification mechanism is an architecture decision, but the product requirement is mandatory.

---

# 14. The Room

## 14.1 Primary places

The room has exactly five primary places:

1. Doorstep
2. Pile
3. Desk
4. Page
5. Drawer

The shared Letter surface, Caught Up state, Settings, Rules, Health, Recovery, and Shortcut Help are not primary places.

## 14.2 Doorstep

The Doorstep is home.

### Quiet state

Shows:

- “No new mail until [time].”
- exact next delivery date and time when helpful,
- whether existing work remains on the Desk,
- a restrained day line with delivery marks,
- shortcuts to the five places,
- health status when anything is wrong.

It must not say “Nothing needs you” when unresolved Desk work exists.

### Arrival state

Shows:

- batch counts,
- prior unfinished intake separately,
- delivery time,
- Start Session,
- direct links to Pile or Desk,
- any partial-release warning.

### In-progress state

Shows:

- remaining unreviewed intake,
- existing work summary without turning the screen into a dashboard,
- leave-session action.

### Health-error state

Shows:

- plain-language problem,
- oldest held-mail age,
- last successful delivery,
- next expected delivery,
- Check Now when safe,
- Panic Release,
- manual Gmail recovery instructions.

## 14.3 Pile

The Pile presents one unreviewed Aware conversation at a time.

The card is already open and includes:

- sender,
- subject,
- timestamp,
- newly released content,
- collapsed quoted history,
- safe attachment list,
- routing explanation on request,
- Open in Gmail.

Primary verbs:

- Next
- Keep
- Skip
- Promote

Secondary actions:

- Reply
- Correct classification
- Show images
- Show original
- Open in Gmail

Requirements:

- Next and Keep remove the item from active intake.
- Skip does not.
- Promote defaults the work item to This Week.
- The Pile must not silently loop skipped items forever.
- The user may leave and return without losing position.
- The next delivery must not reorder the current active Pile unexpectedly.

## 14.4 Desk

The Desk is the only persistent workload list.

Sections appear only when non-empty:

1. New / Unreviewed
2. Needs Sorting
3. Overdue
4. Today
5. This Week
6. Whenever
7. Waiting

Requirements:

- New Needs You items default to This Week but remain in New until acknowledged.
- Needs Sorting contains Unsure items.
- Overdue contains expired Today and This Week commitments.
- Waiting shows elapsed calendar days and the latest outbound timestamp.
- Stable ordering prevents items from jumping during a session.
- The default sort within a section is oldest commitment first, then oldest unreviewed arrival.
- The user can open a Letter, reply, mark Done, or move horizon.
- A Desk item never disappears merely because it was marked read or archived in Gmail.
- Resolving or moving an item gives immediate visible feedback and supports Undo.

## 14.5 Letter

Letter is the shared reading surface used from Pile, Desk, and Drawer.

It includes:

- conversation participants,
- subject,
- full thread,
- clear marking of messages released in the current batch,
- safe rendering,
- collapsed older quoted content,
- attachment controls,
- current classification and work state,
- route explanation,
- correction action,
- Reply and Reply All,
- Open in Gmail.

Requirements:

- Escape returns to the originating place and position.
- A Letter opened from search does not automatically create or alter a work item.
- Merely opening a Letter does not mark an intake item reviewed.
- Unsupported message content produces a clear fallback, not a blank screen.

## 14.6 Page

Page is the full-screen composition space.

It supports:

- New message
- Reply
- Reply All
- To
- Cc
- Bcc
- Subject
- Plain-text-first body
- Basic file attachments
- Draft auto-save
- Draft recovery
- Send
- Discard
- Return to originating context

Behavior:

- Address fields stay visually quiet until needed.
- Reply subject is preserved; changing it is not supported in MVP.
- Reply All excludes the user’s own known identities and removes duplicates.
- The correct Reply-To address is respected.
- Drafts survive navigation, refresh, browser crash, and temporary send failure.
- Discard requires confirmation when content exists.
- Send is protected against duplicate submission.
- A successful send is followed by Done, Waiting, or Keep Open disposition when associated with a work item.
- A failed send leaves the draft and workflow state unchanged.
- Undo Send is explicitly unavailable.
- Advanced formatting and inline images are not part of MVP.

## 14.7 Drawer

Drawer contains search, archive access, and saved views.

It supports:

- Gmail-style query input with documented differences from Gmail’s web UI.
- Message-level search grouped into conversation results.
- Pagination or progressive loading.
- Highlighting of the message that matched.
- Kept items saved view.
- Open Letter.
- Open in Gmail.

Requirements:

- Search is not advertised as exact Gmail UI parity.
- Spam and Trash are excluded by default.
- Search results do not become workload merely by being opened.
- The Drawer is not a browsable folder tree.
- Kept items can be unkept.

## 14.8 Caught Up

Caught Up appears when no released batch item remains unreviewed.

It shows:

- a plain completion statement,
- next delivery time,
- optional quiet acknowledgment of remaining Open or Waiting work,
- leave action,
- direct access to the Desk if desired.

It must not require the Desk to be empty.

## 14.9 Utility overlays

Utility overlays include:

- Settings
- Rules
- Identities
- Notifications
- Health
- Recovery
- Export
- Disconnect
- Shortcut Help
- Appearance and accessibility preferences

These overlays must not introduce a permanent navigation sidebar.

---

# 15. Message Rendering and Attachment Requirements

## 15.1 Safe rendering

The app must treat email content as hostile input.

MVP rendering behavior:

1. Prefer a valid plain-text part when available and readable.
2. Otherwise render sanitized HTML.
3. Block scripts, forms, embedded frames, and active content.
4. Block remote images by default.
5. Allow Show Images for the current message.
6. Clearly identify external links before navigation.
7. Collapse quoted history by default.
8. Preserve meaningful tables and receipt content when safe.
9. Provide Show Original and Open in Gmail.
10. Never render raw unsafe HTML directly in the room.

Generalized newsletter “reader mode” extraction is deferred.

## 15.2 Attachments

Reading requirements:

- Show filename, type, and size.
- Download through a safe attachment flow.
- Preview only supported safe types.
- Prevent unsafe inline execution.
- Surface unsupported or unavailable attachments clearly.

Sending requirements:

- Add and remove ordinary file attachments.
- Enforce Gmail’s current provider limits.
- Preserve draft attachments.
- Show upload and send failures.
- Prevent the user from assuming a file was attached when it failed.
- Inline images, cloud-drive attachment workflows, and attachment libraries are deferred.

Calendar invitations, forwarded message files, and unusual MIME content may require Open in Gmail.

---

# 16. Search Requirements

Search must:

- Accept the provider’s supported Gmail query language where feasible.
- Explain that some Gmail web-interface behavior may differ.
- Group results by conversation.
- Indicate the matching message.
- Support sender, recipient, subject, date, label, attachment, and quoted terms when supported.
- Preserve the query when returning from a Letter.
- Never alter classification or work status solely because a result was opened.
- Offer Open in Gmail for unsupported or ambiguous searches.
- Keep recent queries local to the user and clearable.
- Avoid exposing message content in logs or telemetry.

---

# 17. Keyboard and Interaction Requirements

The room is keyboard-first but not keyboard-exclusive.

Proposed baseline shortcuts:

| Action | Shortcut |
|---|---|
| Doorstep / Pile / Desk / Page / Drawer | `1`–`5` |
| Move through lists | `j` / `k` |
| Next or acknowledge default action | `Space` |
| Reply | `r` |
| Done | `e` |
| Change horizon | `h` |
| Keep / save awareness item | `s` |
| Promote to Needs You | `p` |
| Search | `/` |
| Close or return | `Esc` |
| Shortcut help | `?` |

Requirements:

- No shortcut collisions.
- Single-letter global shortcuts are disabled while typing in any input or editor.
- Every shortcut has an accessible clickable equivalent.
- Focus movement is visible and predictable.
- Destructive or broad actions require confirmation.
- Keyboard behavior is included in end-to-end tests.

---

# 18. Visual and Accessibility Requirements

## 18.1 Visual language

- Black on white and white on black.
- Grayscale metadata.
- One typeface family.
- Limited type sizes.
- One accent color used only for Needs You.
- Reading measure near 65–75 characters.
- Generous space.
- Sender, subject, and time as quiet metadata.
- Motion only for meaningful transitions.
- No avatars, badges, streaks, ambient sound, or decorative dashboards.

Typeface selection occurs during Room prototyping and is not a Phase 0 blocker.

## 18.2 Accessibility

The MVP must support:

- Complete keyboard operation.
- Visible focus.
- Semantic headings and landmarks.
- Screen-reader labels and state announcements.
- Reduced-motion preference.
- Sufficient contrast in light and dark modes.
- Browser zoom without loss of function.
- No state communicated only by color.
- Accessible error messages.
- Accessible attachment controls.
- Accessible notification permission flow.
- Responsive access to health, recovery, Check Now, and emergency peek on a phone.

---

# 19. Settings Requirements

Settings must support:

- Delivery windows.
- Enabled days.
- Timezone.
- Notifications.
- Routing rules.
- Bypass rules.
- Known email identities.
- Optional disabled heuristics.
- Appearance.
- Accessibility preferences.
- Gmail connection status.
- App-owned label and interception health.
- Last successful release.
- Oldest held-message age.
- Manual synchronization.
- Check Now.
- Emergency peek.
- Panic release.
- Export.
- Safe disconnect.

Dangerous recovery actions must be grouped separately and explained in plain language.

---

# 20. Reliability and Recovery Requirements

## 20.1 Release reliability

- Scheduled and manual releases cannot overlap.
- Repeated execution of the same release is harmless.
- Partial failure is recorded per message.
- A release is not marked complete while selected messages remain unresolved.
- Transient failures are retried.
- Permanent failures are surfaced.
- A missed schedule is detected.
- The system can resume after interruption without duplicating work.
- New mail arriving during release remains held for the next batch.
- The user can see last successful release and next expected release.

## 20.2 Held-mail grace period

The product must define an operational grace period after a scheduled window. The initial default is 15 minutes.

If held mail remains unreleased beyond the grace period:

- the Doorstep displays a critical warning,
- a health alert is issued through a channel independent of intercepted Gmail,
- Check Now is offered when safe,
- Panic Release is available,
- manual Gmail recovery is shown.

## 20.3 Interception health

The app must verify:

- account authorization,
- expected app-owned labels,
- interception behavior,
- release capability,
- scheduler health,
- oldest held-mail age.

If interception is active but the app cannot release, the state is critical.

## 20.4 Fail-safe behavior

Before implementation proceeds beyond Phase 0, the project must choose and validate one acceptable fail-safe strategy:

- a proven fail-open interception mechanism, or
- reliable independent health alerting plus tested panic and manual recovery.

The chosen behavior must ensure that future mail cannot remain trapped indefinitely without detection.

## 20.5 Data recovery

The user can export:

- delivery-window settings,
- identities,
- rules,
- bypass rules,
- work-item state,
- Waiting state,
- Keep state,
- workflow event history sufficient for troubleshooting.

Email bodies do not need to be exported because Gmail remains the mail source.

---

# 21. Security and Privacy Requirements

The MVP must:

- Restrict access to the configured Google account identity.
- Prevent another Google account from entering the same single-user environment.
- Protect account authorization and session state.
- Keep authorization secrets out of browser storage.
- Avoid logging message bodies, subjects, recipients, attachment names, or authorization tokens.
- Redact provider error details before storing diagnostic events.
- Sanitize all email HTML.
- Prevent header injection and malformed-recipient submission.
- Protect every state-changing web action against cross-site request forgery.
- Use restrictive browser content policies appropriate for hostile email.
- Scan filenames and content disposition safely.
- Preserve a clear audit trail of workflow transitions without duplicating message bodies.
- Allow the user to delete local product metadata after safe disconnect.
- Document what metadata is retained and for how long.
- Minimize permanent local caching of full message bodies.
- Protect drafts and attachments at the same level as email content.
- Ensure health alerts do not disclose sensitive message content.

A separate security review is required before dogfood begins.

---

# 22. Performance and Volume Requirements

The MVP must define and test target performance for:

- Doorstep load.
- Desk load.
- Opening a Letter with cached metadata.
- Opening a Letter requiring provider retrieval.
- Pile transition.
- Draft save.
- Search.
- Release batches of 10, 100, and 500 messages.
- Conversations with large histories.
- Multiple attachments.
- Provider throttling and backoff.

Product-level expectations:

- Pile actions should feel immediate.
- Workflow transitions should update optimistically only when they can be safely reversed.
- Sending must not appear successful before provider confirmation.
- Large deliveries must remain finite and navigable.
- A batch that exceeds a practical one-card-at-a-time limit must display a clear count and allow the user to leave and resume without loss.

Exact numerical latency budgets are finalized in the architecture and test plan, but the user experience must not depend on a permanently loaded full mailbox.

---

# 23. Observability and Audit Requirements

The product must expose or record:

- last successful account synchronization,
- last successful scheduled release,
- last successful manual release,
- oldest held-message age,
- current held count,
- batch status,
- partial failures,
- routing reason,
- rule creation and deletion,
- work-item transitions,
- send attempts and confirmed sends,
- panic-release results,
- disconnect results,
- external Gmail conflicts.

Diagnostic records must avoid sensitive email content.

The user-facing Health view must translate technical failures into plain-language consequences and recovery actions.

---

# 24. Test Strategy

## 24.1 Domain and rule tests

Test:

- every routing rule,
- every precedence combination,
- explicit-rule override behavior,
- address normalization,
- send-as identity handling,
- mailing-list detection,
- previous-correspondent detection,
- optional direct-recipient heuristic,
- mixed-message conversation aggregation,
- every work-state transition,
- horizon rollover,
- daylight-saving transitions,
- correction and undo,
- duplicate release replay,
- duplicate send prevention.

## 24.2 Invariant tests

Automated tests must continuously verify:

- Held and Released are mutually exclusive.
- One effective classification per conversation.
- One status per work item.
- One horizon for Open work.
- No horizon for Waiting or Resolved.
- New messages after a snapshot remain held.
- User rules always beat system heuristics.
- Aware cannot automatically demote Needs You.
- A human reply reactivates Waiting.
- Failed sends do not change work state.
- Repeated transitions are idempotent.

## 24.3 Real Gmail integration tests

Use a dedicated Gmail test account and repeatable sender fixtures.

Test:

- direct primary-address delivery,
- send-as alias,
- plus-address,
- forwarding,
- Bcc,
- mailing list,
- category labels,
- no-reply transactional mail,
- multiple messages in one thread,
- reply to an existing labeled thread,
- attachment,
- calendar invitation,
- password reset or authentication code,
- message arrival during release,
- Gmail mobile notifications,
- Gmail badge behavior,
- Inbox added after initial delivery,
- existing user filters,
- external Gmail reply,
- external archive, read, trash, and label changes,
- authorization revocation,
- missing or renamed app-owned labels.

## 24.4 End-to-end tests

Required scenarios:

1. Held arrival → scheduled release → Aware → Next → Caught Up.
2. Held arrival → Needs You → acknowledge This Week → Gmail Inbox clears → Desk remains open.
3. Unsure → Just This Conversation → Aware.
4. Unsure → persistent sender rule → next message routes automatically.
5. Aware → Promote → This Week.
6. Needs You → Reply → Waiting.
7. Waiting → human reply → next delivery → Needs You.
8. Waiting → automated response → remains Waiting.
9. Compose → draft recovery after browser restart.
10. Send failure → draft preserved → workflow unchanged.
11. Duplicate send submission → one confirmed outgoing message.
12. Check Now concurrent with scheduled release → one batch only.
13. Worker interruption before release mutation.
14. Interruption after some messages release.
15. New message arrives after snapshot.
16. OAuth revoked while interception remains active.
17. Panic release.
18. Safe disconnect with held mail.
19. External Gmail reply → disposition prompt.
20. Malicious HTML and remote tracking image.
21. Unsupported attachment → clear Gmail fallback.
22. Two browser tabs act on the same item.
23. Previous batch unfinished when next delivery arrives.
24. Every Pile item skipped → no false Caught Up.

## 24.5 Accessibility tests

- Keyboard-only completion of every normal workflow.
- Screen-reader traversal.
- Focus restoration after Letter and overlays.
- Reduced-motion behavior.
- 200% zoom.
- Contrast in light and dark.
- Error announcements.
- Mobile access to recovery actions.

## 24.6 Failure-injection tests

Deliberately simulate:

- provider throttling,
- network timeouts,
- expired authorization,
- missing filter,
- missing label,
- partial label mutation,
- repeated scheduler invocation,
- stale browser state,
- failed attachment upload,
- ambiguous send timeout,
- unavailable thread,
- notification permission denial,
- notification delivery failure.

---

# 25. Dogfood Measurement Plan

## 25.1 Baseline period

Before enabling interception, record at least several normal-use days:

- approximate email checks per day,
- Gmail notifications per day,
- incoming message volume,
- action-required percentage,
- time spent per email session,
- number of open loops,
- frequency of returning to Gmail search,
- subjective email stress from 1 to 5,
- frequency of ending the day feeling caught up.

## 25.2 Dogfood instrumentation

Measure:

- scheduled deliveries completed,
- delayed or failed deliveries,
- oldest held-message age,
- Check Now use,
- emergency peek use,
- bypass volume,
- Needs You → Aware corrections,
- Aware → Needs You corrections,
- Unsure percentage,
- persistent rules created,
- batch size,
- time to clear intake,
- percentage of batches reaching Caught Up,
- open Gmail fallback actions,
- replies sent in the app,
- attachment fallback,
- drafts recovered,
- send failures,
- notification failures or duplicates,
- Waiting reactivations,
- daily subjective stress.

## 25.3 Provisional success gates

The product proceeds beyond the initial dogfood only if:

### Absolute safety gates

- Zero silently lost messages.
- Zero unrecoverable held messages.
- Zero duplicate sends.
- Zero completed releases that silently omit snapshot messages.
- Panic release and safe disconnect work in real use.

### Reliability gates

- At least 95% of scheduled releases complete without manual intervention.
- Every failed release becomes visible before the held-mail grace period expires.
- No critical health warning depends solely on the held Gmail account.

### Behavioral gates

- Unscheduled checking falls by at least 50% relative to baseline by the second week.
- At least 75% of deliveries reach Caught Up in one deliberate session.
- Gmail fallback is needed for fewer than 10% of ordinary conversations, excluding intentionally deferred features such as forwarding.
- Subjective email stress improves by at least one point on the five-point scale on most days in the second week.
- The user chooses to continue using the product after the formal two-week test.

### Routing gates

- Aware → Needs You false-negative corrections fall below 2% in the second week.
- Unsure falls below 15% of released conversations by the end of the second week.
- Every misroute can be explained and corrected.

These thresholds are provisional and may be adjusted once baseline data exists, but the absolute safety gates are not negotiable.

---

# 26. Phased Implementation Plan

The phases are ordered by risk. The project must prove safe interception and release before investing in a polished room.

---

## Phase 0 — Product Contract and Gmail Feasibility

### Goal

Validate the product’s most dangerous assumptions and freeze the behavioral contract before full implementation.

### Milestone 0.1 — State and workflow contract

**Deliverables**

- Final terminology.
- State model.
- Invariants.
- Transition table.
- Caught Up definition.
- Horizon calendar semantics.
- Waiting reactivation behavior.
- External Gmail behavior policy.
- Rule precedence.
- Resolved product decisions.

**Acceptance criteria**

- Every primary action has a defined before-state and after-state.
- Illegal state combinations are listed.
- No open product question blocks routing, Desk behavior, Caught Up, or Waiting.
- Product, design, implementation, and QA can independently describe the same behavior.

### Milestone 0.2 — Gmail interception test matrix

**Deliverables**

- Dedicated Gmail test account.
- Verified receiving identities.
- Controlled sender fixtures.
- Test results for primary address, aliases, plus addressing, forwarding, Bcc, mailing lists, categories, no-reply mail, thread replies, attachments, calendar invitations, and authentication codes.
- Evidence of how existing Gmail filters interact with interception.

**Acceptance criteria**

- Every intended receiving identity is either reliably intercepted or explicitly excluded.
- Held mail remains directly discoverable in Gmail.
- New messages in existing threads do not inherit incorrect workflow state.
- The project documents known provider limitations and accepted constraints.
- No assumption about thread-level labels remains untested.

### Milestone 0.3 — Notification and badge feasibility

**Deliverables**

- Device-level test results for held-mail notifications.
- Gmail unread/badge behavior.
- Results of adding Inbox later.
- Batch-release notification behavior.
- Decision on product-controlled notification requirement.

**Acceptance criteria**

- The product no longer assumes Gmail provides one batch alert.
- The chosen notification behavior can satisfy at-most-one app batch alert.
- Held-mail badge behavior is understood and accepted.
- Notification failure does not block release.

### Milestone 0.4 — Failure and recovery proof

**Deliverables**

- Simulated account revocation.
- Simulated scheduler failure.
- Simulated partial release.
- Panic-release prototype.
- Direct Gmail recovery rehearsal.
- Safe-disconnect rehearsal.
- Decision on fail-open behavior or independent health alerting.

**Acceptance criteria**

- Held mail can be restored after the app’s normal workflow is unavailable.
- Future interception is disabled before recovery.
- Re-running recovery is safe.
- The user can complete direct Gmail recovery without developer intervention.
- A broken release cannot remain silent beyond the grace period.

### Phase 0 exit gate

Do not begin full Room implementation until:

- interception coverage is known,
- release snapshots are proven,
- notification behavior is understood,
- panic release works,
- manual recovery works,
- safe disconnect works,
- state semantics are approved.

---

## Phase 1 — Safe Account Connection and Interception

### Goal

Create a safe, understandable foundation for using a real Gmail account.

### Milestone 1.1 — Account connection and identity setup

**Deliverables**

- Single-account authorization.
- Configured-user restriction.
- Primary address discovery.
- Known send-as identity discovery.
- Manual receiving-identity entry.
- Connection status.
- Authorization-loss state.

**Acceptance criteria**

- Only the configured user can access the product.
- The app displays exactly which Gmail account is connected.
- The user can review all identities covered by interception.
- A missing identity blocks activation or produces an explicit warning.
- Authorization loss is visible and does not masquerade as an empty inbox.

### Milestone 1.2 — App-owned Gmail resources

**Deliverables**

- Namespaced labels.
- Interception setup.
- Verification checks.
- Setup rollback.
- Manual-recovery instructions.

**Acceptance criteria**

- Interception is enabled last, after all required labels and checks exist.
- Partial setup cannot leave hidden active interception.
- Labels are visible and understandable in Gmail.
- The app can detect missing or altered resources.
- No message is deleted, trashed, or marked spam.

### Milestone 1.3 — Onboarding safety rehearsal

**Deliverables**

- Test-message flow.
- Test-release flow.
- User confirmation that held mail is visible in Gmail.
- Recovery-instructions acknowledgment.
- Initial timezone and delivery window.
- Initial notification preference.

**Acceptance criteria**

- The user observes one message being held and released before activation completes.
- The user can find the Held label without the app.
- The user sees next delivery time in local time.
- Failed rehearsal leaves ordinary Gmail delivery unchanged.

### Milestone 1.4 — Health, panic release, and disconnect

**Deliverables**

- Health utility.
- Oldest-held age.
- Last successful release.
- Interception status.
- Panic release.
- Safe disconnect.
- Export.

**Acceptance criteria**

- Panic release disables future interception before restoring mail.
- Disconnect cannot revoke account access while held mail remains without explicit override.
- Partial recovery is reported accurately.
- Export excludes message bodies by default.
- Critical health state is accessible from desktop and phone layouts.

### Phase 1 exit gate

The connected account can be safely activated, monitored, recovered, and disconnected before scheduled delivery is introduced.

---

## Phase 2 — Reliable Delivery Batches

### Goal

Implement finite, repeatable, observable scheduled and manual delivery.

### Milestone 2.1 — Window and calendar behavior

**Deliverables**

- One default daily window.
- Additional opt-in windows.
- Day-of-week controls.
- Timezone behavior.
- Daylight-saving handling.
- Next-delivery calculation.
- Missed-window behavior.

**Acceptance criteria**

- The Doorstep always displays the correct next local delivery.
- Duplicate windows are rejected.
- Timezone changes preview their effect.
- DST tests pass.
- A missed delivery becomes visible and recoverable.

### Milestone 2.2 — Frozen release batches

**Deliverables**

- Exact message snapshot.
- Per-message release state.
- Conversation grouping.
- Stable batch counts.
- Manual and scheduled batch distinction.
- Retry-safe completion.

**Acceptance criteria**

- Messages arriving after snapshot stay held.
- A release can restart after interruption.
- Running the same release twice does not duplicate state.
- Batch counts remain stable.
- A partial failure cannot appear as success.
- Releases support more than one provider result page.

### Milestone 2.3 — Check Now and concurrency control

**Deliverables**

- Deliberate Check Now action.
- Account-level release exclusion.
- Manual batch record.
- In-app suppression of redundant notification when appropriate.

**Acceptance criteria**

- Check Now cannot race a scheduled release.
- Repeated clicks do not create duplicate batches.
- Check Now uses the exact same routing and safety behavior.
- Usage is measurable.

### Milestone 2.4 — Synchronization and reconciliation

**Deliverables**

- Initial account synchronization.
- Incremental synchronization.
- Recovery when incremental history is unavailable.
- External Gmail change handling.
- Stale-browser conflict handling.

**Acceptance criteria**

- New inbound and outbound mail becomes visible without a full mailbox reload.
- External replies are detected.
- Gmail read/archive changes do not silently resolve work.
- External sends create a disposition prompt.
- Two browser tabs cannot silently overwrite one another.
- Missing history triggers safe reconciliation rather than silent gaps.

### Milestone 2.5 — Batch notification

**Deliverables**

- One notification for non-empty scheduled batches.
- Stable counts.
- Doorstep deep link.
- Permission-denied state.
- Notification failure telemetry.
- Independent critical health alert path.

**Acceptance criteria**

- No per-message app notifications occur.
- Notification counts match the batch.
- Release succeeds even when notification fails.
- Health alerts do not depend solely on intercepted Gmail.

### Phase 2 exit gate

The postman can repeatedly hold and release finite batches without races, silent omissions, or unsafe dependency on the Room.

---

## Phase 3 — Deterministic Routing and Learning

### Goal

Classify mail predictably and let the user improve routing without losing control.

### Milestone 3.1 — Built-in routing

**Deliverables**

- Bulk/list header rules.
- Automated-sender patterns.
- Gmail category signals.
- Previous-correspondent rule.
- Unsure fallback.
- Route explanation.

**Acceptance criteria**

- First-match behavior is deterministic.
- Every route has an explanation.
- Contacts are not required.
- Built-in heuristics never bypass delivery.
- The disabled direct-recipient heuristic remains off by default.

### Milestone 3.2 — User rules and precedence

**Deliverables**

- Conversation overrides.
- Exact-sender rules.
- Mailing-list rules.
- Domain rules.
- Rule editing, disabling, deleting, and conflict display.

**Acceptance criteria**

- User rules always beat built-in heuristics.
- Domain rules require explicit confirmation.
- Rule changes affect future releases.
- Historical route records remain explainable.
- Conflicts do not resolve silently.

### Milestone 3.3 — Corrections and Undo

**Deliverables**

- Correction from Pile, Desk, and Letter.
- Just This Conversation default.
- Persistent-rule option.
- Previewed scope.
- Undo.

**Acceptance criteria**

- A one-time correction does not create a permanent rule.
- Undo restores classification and removes any newly created rule.
- Active work state updates immediately and consistently.
- Corrections are measured without recording message content.

### Milestone 3.4 — Bypass rules

**Deliverables**

- Explicit sender, list, and domain bypass rules.
- Rule explanation.
- Immediate-delivery warning.
- Usage tracking.
- Disable and delete.

**Acceptance criteria**

- No heuristic can create bypass.
- Bypass rules are visually distinct from classification rules.
- The user understands bypassed mail may generate normal Gmail notifications.
- Bypassed mail can still create or update app work after synchronization.

### Milestone 3.5 — Conversation aggregation

**Deliverables**

- Mixed-message precedence.
- Existing-work protection.
- Waiting-reply override.
- Multi-message highlighting.
- Distinct-conversation counts.

**Acceptance criteria**

- Automatic Aware never demotes Needs You.
- Mixed batches use Needs You > Unsure > Aware.
- Multiple new messages in one thread count once.
- Every newly released message remains visible in the Letter.

### Phase 3 exit gate

A real delivery can be routed, explained, corrected, and improved without ambiguous permanent rules or silent demotion of action mail.

---

## Phase 4 — Reading and Triage Room

### Goal

Let the user process incoming awareness and action mail to a real intake finish line.

### Milestone 4.1 — Doorstep and Caught Up

**Deliverables**

- Quiet state.
- Arrival state.
- In-progress state.
- Health-error state.
- Prior-incomplete intake state.
- Caught Up.

**Acceptance criteria**

- Doorstep distinguishes “no new mail” from “no open work.”
- Counts use distinct conversations.
- Caught Up is reachable with Open and Waiting work remaining.
- A new batch does not erase an older unfinished batch.
- Partial releases are visibly incomplete.

### Milestone 4.2 — Safe Letter rendering

**Deliverables**

- Full conversation surface.
- New-message highlighting.
- Plain text.
- Sanitized HTML.
- Remote image blocking.
- Collapsed quoted history.
- Unsupported-content fallback.
- Open in Gmail.

**Acceptance criteria**

- Malicious HTML cannot execute active content.
- Tracking images are not loaded by default.
- Unsupported content is never rendered as a blank message.
- Escape returns to the correct source and position.
- Opening alone does not mark reviewed.

### Milestone 4.3 — Attachment reading

**Deliverables**

- Attachment metadata.
- Safe download.
- Supported preview.
- Unsupported-type handling.

**Acceptance criteria**

- Filename, type, and size are visible.
- Failed downloads are clear and retriable.
- Unsafe content is not executed.
- Calendar and unusual message formats provide Gmail fallback.

### Milestone 4.4 — Pile

**Deliverables**

- One Aware item at a time.
- Next.
- Keep.
- Skip.
- Promote.
- Resume position.
- Correction.
- Reply access.

**Acceptance criteria**

- Next and Keep mark reviewed.
- Skip does not mark reviewed.
- Promote creates Open / This Week.
- All-skipped state does not show Caught Up.
- Returning to Pile preserves progress.
- Pile order remains stable during a session.

### Milestone 4.5 — Desk and horizons

**Deliverables**

- New.
- Needs Sorting.
- Overdue.
- Today.
- This Week.
- Whenever.
- Waiting.
- Horizon changes.
- Done.
- Undo.

**Acceptance criteria**

- New Needs You items default to This Week.
- Acknowledgment is explicit.
- Today and This Week become Overdue without silent rollover.
- Waiting has no horizon.
- Done removes active obligation but preserves the conversation.
- External Gmail read/archive changes do not move Desk state.
- Every non-send transition is undoable.

### Milestone 4.6 — Drawer and Keep

**Deliverables**

- Search.
- Grouped conversation results.
- Matching-message indication.
- Query preservation.
- Keep saved view.
- Open in Gmail.

**Acceptance criteria**

- Search does not claim exact Gmail UI parity.
- Opening a result does not create work.
- Kept items are retrievable and removable.
- Spam and Trash are excluded by default.
- Unsupported queries fail clearly.

### Phase 4 exit gate

The user can read and process a complete delivery, reach Caught Up, and retain all open obligations on the Desk without composing mail.

---

## Phase 5 — Compose, Reply, and Open Loops

### Goal

Support enough real correspondence that Gmail is a fallback rather than the normal place to finish work.

### Milestone 5.1 — New compose and draft recovery

**Deliverables**

- Full-screen Page.
- To, Cc, Bcc, Subject.
- Plain-text body.
- Auto-save.
- Crash recovery.
- Discard.
- Basic attachments.

**Acceptance criteria**

- Draft survives navigation and browser restart.
- Discard confirms when content exists.
- Failed attachment upload is visible.
- A draft cannot be mistaken for sent mail.
- Single-letter global shortcuts are disabled in the editor.

### Milestone 5.2 — Reply and Reply All

**Deliverables**

- Correct conversation association.
- Reply-To handling.
- Self-identity exclusion.
- Recipient de-duplication.
- Preserved subject.
- Quoted-context behavior.

**Acceptance criteria**

- Replies remain in the intended Gmail conversation.
- Reply All never includes the user’s own known identities.
- Duplicate recipients are removed.
- Reply subject cannot be accidentally changed into a broken thread.
- Large recipient sets remain inspectable before send.

### Milestone 5.3 — Sending and duplicate protection

**Deliverables**

- Confirmed send state.
- Failure state.
- Retry.
- Duplicate-submit prevention.
- Attachment send status.

**Acceptance criteria**

- One user action produces at most one outgoing message.
- Ambiguous timeout does not trigger an unsafe automatic resend.
- Failed send preserves the draft.
- Workflow state changes only after confirmed send.
- Undo Send is not implied.

### Milestone 5.4 — Post-send disposition

**Deliverables**

- Done.
- Waiting.
- Keep Open.
- Expect a Reply for new messages.
- Return to originating place.

**Acceptance criteria**

- Disposition occurs after successful send.
- Waiting clears the horizon and records start time.
- Done resolves the work item.
- Keep Open preserves the current horizon.
- New outbound mail creates Waiting only by explicit user choice.

### Milestone 5.5 — Waiting reactivation

**Deliverables**

- Human-reply detection.
- Automated-response exclusion.
- Needs You reactivation.
- Batch inclusion.
- “Name replied” delight.

**Acceptance criteria**

- Human replies do not silently disappear.
- Reply arrival moves Waiting to Open / Needs You.
- The new reply is unreviewed in the next batch.
- Obvious bounce or auto-response does not close Waiting.
- External Gmail replies follow the same incoming behavior.

### Milestone 5.6 — External-send reconciliation

**Deliverables**

- Detection of an outgoing reply sent in Gmail.
- Done / Waiting / Keep Open prompt.
- Conflict handling.

**Acceptance criteria**

- External sends are reflected.
- The app does not silently guess the disposition.
- The prompt remains visible until resolved.
- A stale app draft cannot overwrite an external send.

### Phase 5 exit gate

The user can complete ordinary new mail, replies, attachments, and waiting loops in the app without unsafe send behavior.

---

## Phase 6 — Usability, Security, and Operational Hardening

### Goal

Make the MVP dependable enough for two weeks of real-account use.

### Milestone 6.1 — Keyboard and accessibility

**Deliverables**

- Final shortcut map.
- Shortcut help.
- Focus management.
- Screen-reader semantics.
- Reduced motion.
- Zoom and contrast support.
- Mobile recovery access.

**Acceptance criteria**

- Every normal workflow is keyboard-completable.
- No shortcut fires while typing.
- Screen-reader and 200% zoom tests pass.
- State is never color-only.
- Recovery works from a phone browser.

### Milestone 6.2 — Visual bones

**Deliverables**

- Typeface decision.
- Grayscale hierarchy.
- One Needs You accent.
- Light and dark modes.
- Reading measure.
- Meaningful motion only.

**Acceptance criteria**

- All five places are visually distinct without a sidebar.
- The accent is used only for Needs You.
- Motion respects reduced-motion settings.
- The interface remains legible without animation.
- No decorative metrics or gamification appear.

### Milestone 6.3 — Security review

**Deliverables**

- Authorization review.
- Session review.
- HTML-sanitization review.
- Attachment review.
- logging and telemetry review.
- draft and metadata retention review.
- abuse and injection tests.

**Acceptance criteria**

- No message content or secrets appear in logs.
- Malicious HTML tests pass.
- Header injection is blocked.
- The configured-user restriction is enforced.
- Disconnect and metadata deletion behavior are documented.
- High-severity findings are resolved before dogfood.

### Milestone 6.4 — Reliability and failure injection

**Deliverables**

- Concurrency tests.
- release interruption tests.
- provider throttling tests.
- authorization-loss tests.
- missing-resource tests.
- panic-release tests.
- ambiguous send tests.
- large-batch tests.

**Acceptance criteria**

- No silent loss.
- No duplicate send.
- No snapshot race.
- Critical failure is visible before grace-period expiry.
- Panic release works after simulated partial failure.
- Large batches remain resumable.

### Milestone 6.5 — Settings and supportability

**Deliverables**

- Complete Settings.
- Rules.
- Identities.
- Notifications.
- Health.
- Recovery.
- Export.
- Disconnect.
- Plain-language support copy.

**Acceptance criteria**

- The user can understand and act on every health error.
- Broad rules are identifiable and editable.
- Manual recovery instructions remain accessible without a healthy release system.
- Export succeeds before disconnect.
- There are no hidden admin-only recovery steps required for ordinary failures.

### Phase 6 exit gate

All safety, security, accessibility, and failure tests pass. The app is ready for controlled real-account dogfood.

---

## Phase 7 — Two-Week Dogfood and Product Decision

### Goal

Test the behavioral thesis with real daily use and determine whether to continue, revise, or stop.

### Milestone 7.1 — Baseline capture

**Deliverables**

- Baseline check frequency.
- Notification volume.
- message volume.
- fallback behavior.
- open-loop count.
- stress rating.
- session duration.

**Acceptance criteria**

- Baseline data is sufficient to compare behavior.
- Measurement does not store sensitive message content.
- Success gates are reviewed and finalized.

### Milestone 7.2 — Controlled activation

**Deliverables**

- Real account connected.
- One daily delivery.
- minimal bypass list.
- health alerts enabled.
- recovery rehearsal completed.
- daily reflection prompt.

**Acceptance criteria**

- Activation checklist passes.
- Panic release was rehearsed immediately before activation.
- The user can locate Held mail in Gmail.
- No unresolved critical health warning exists.

### Milestone 7.3 — Daily operation

**Deliverables**

- Two weeks of use.
- incident log.
- correction metrics.
- fallback metrics.
- session completion data.
- qualitative notes.

**Acceptance criteria**

- Safety incidents are investigated immediately.
- A severe safety failure pauses interception until resolved.
- Product-friction notes distinguish missing MVP capability from architecture or performance issues.
- No metric is used as a gamified score in the normal interface.

### Milestone 7.4 — Evaluation and disposition

**Deliverables**

- Comparison to baseline.
- Safety report.
- routing report.
- Room usability report.
- Gmail fallback report.
- decision memo.

**Possible outcomes**

1. **Proceed** — thesis supported; prepare v1.1.
2. **Revise and repeat** — safety is sound but behavior or workflow needs targeted changes.
3. **Stop** — scheduled delivery or the Room does not improve email enough to justify continued development.

**Acceptance criteria**

- Every provisional success gate is evaluated.
- Failures are separated into product, usability, integration, and implementation categories.
- The decision memo lists evidence, not enthusiasm.
- No v1.1 feature is accepted merely because it is interesting; it must address observed evidence.

---

# 27. Cross-Phase Dependencies

| Dependency | Must be complete before |
|---|---|
| State contract | Routing, Desk, Waiting, Caught Up |
| Interception feasibility | Real-account connection |
| Recovery proof | Scheduled release |
| Frozen batch semantics | Doorstep counts and Pile |
| Deterministic routing | Pile and Desk intake |
| Safe rendering | Real-message Letter |
| Synchronization | Waiting reactivation and Gmail fallback |
| Send duplicate protection | Real-account compose |
| Security review | Dogfood activation |
| Panic release | Dogfood activation |
| Measurement baseline | Two-week evaluation |

Room polish may proceed in parallel with later Postman work only against fixed test fixtures. It must not be treated as evidence that the real delivery system is ready.

---

# 28. MVP Release Checklist

## Product semantics

- [ ] State model approved.
- [ ] Caught Up definition approved.
- [ ] Horizons and overdue behavior approved.
- [ ] Waiting reactivation approved.
- [ ] Rule precedence approved.
- [ ] External Gmail behavior approved.

## Account and delivery safety

- [ ] All receiving identities verified.
- [ ] Controlled hold and release test passed.
- [ ] Manual Gmail recovery rehearsed.
- [ ] Panic release passed.
- [ ] Safe disconnect passed.
- [ ] Independent health alert passed.
- [ ] Oldest-held warning passed.
- [ ] Partial-release recovery passed.
- [ ] New-mail-during-release test passed.

## Routing

- [ ] Built-in rules tested.
- [ ] User rules override heuristics.
- [ ] Corrections default to Just This Conversation.
- [ ] Domain-rule warning works.
- [ ] Route explanation visible.
- [ ] Mixed-thread aggregation tested.
- [ ] Bypass rules explicit only.

## Room

- [ ] Doorstep states complete.
- [ ] Pile Next / Keep / Skip / Promote complete.
- [ ] Desk sections complete.
- [ ] Letter safe rendering complete.
- [ ] Attachments readable.
- [ ] Drawer search and Keep complete.
- [ ] Caught Up reachable with open Desk work.
- [ ] No false empty state.

## Compose

- [ ] Draft recovery passed.
- [ ] Reply and Reply All passed.
- [ ] Self-identities excluded.
- [ ] Duplicate send prevention passed.
- [ ] Attachment send passed.
- [ ] Failed send preserves state.
- [ ] Done / Waiting / Keep Open disposition works.
- [ ] External Gmail send reconciliation works.

## Quality

- [ ] Keyboard workflows passed.
- [ ] Screen-reader review passed.
- [ ] Reduced-motion passed.
- [ ] 200% zoom passed.
- [ ] Malicious HTML tests passed.
- [ ] No sensitive logging.
- [ ] Two-tab conflicts handled.
- [ ] Large-batch tests passed.
- [ ] Security review complete.
- [ ] Baseline measurement ready.

---

# 29. Post-MVP Candidate Backlog

These items are intentionally deferred until dogfood evidence supports them:

- Two or more default delivery windows.
- Person-centric Desk.
- End-of-session and weekly reflection.
- AI suggestions for Unsure.
- Draft suggestions in the user’s voice.
- Conversation summaries.
- Natural-language rules.
- Newsletter bundles.
- Sender bundles.
- Generalized reader mode.
- Local subject aliases.
- Contact notes.
- Attachment library.
- Forwarding.
- Calendar invitation actions.
- Markdown-to-HTML sending.
- Inline images.
- Send later.
- Native applications.
- Multiple accounts.
- Outlook or IMAP.
- Public-user onboarding.
- Billing.
- Team or shared inboxes.

Every backlog item must cite an observed dogfood problem or validated opportunity before entering implementation planning.

---

# 30. Definition of Implementation Ready

This specification is ready to hand to implementation only when:

1. Phase 0 evidence is attached.
2. All product decisions in this document are accepted or explicitly amended.
3. The state-transition contract is represented in executable tests or an equivalent formal artifact.
4. The Gmail test matrix has no unexplained critical gaps.
5. Panic release and safe disconnect have passed against a real test account.
6. The separate technology and architecture document satisfies the product behaviors and safety requirements defined here.
7. No implementation choice contradicts the finite-batch, user-control, deterministic-routing, or recovery principles.
8. Every Phase 1 milestone can be built without inventing new product semantics.

The order of work matters:

> **Prove interception and recovery first. Prove finite delivery second. Prove routing third. Build the room fourth. Add sending fifth. Harden everything before real-account dogfood.**

A beautiful room on top of an unsafe postman is not a viable product.
