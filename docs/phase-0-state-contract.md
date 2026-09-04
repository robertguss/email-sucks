# Phase 0 state and workflow contract

Date: 2026-09-04

Status: implementation contract selected under the owner's autonomous-work instruction. This completes the written portion of milestone 0.1. It does not prove Gmail behavior or pass the Phase 0 exit gate. Defaults below are engineering decisions, not claims of individual owner approval. Device-dependent read/unread behavior and arrival-time bypass support remain experiment gates.

This supplements [product specification sections 6–13](email-client-product-implementation-spec.md#6-terminology). Where those sections leave timing or conflict handling open, this document defines the implementation behavior. The [proof plan](phase-0-gmail-reliability-proof.md) remains the authority for live evidence.

## State ownership and identity

| Entity | Authoritative state | Identity / constraints |
|---|---|---|
| Gmail message | Provider content, labels, existence, read/unread | Account + Gmail message ID; operations target messages, never whole threads |
| Delivery record | Policy Hold/Bypass; state Held/Released/Bypassed; release outcome | One per managed incoming message; existing mailbox history is not automatically managed |
| Conversation | Effective Needs You/Aware/Unsure, Keep, explicit override and revision | Account + Gmail thread ID; classification is independent of Gmail labels |
| Work item | Open/Waiting/Resolved; horizon and date; history | At most one current work item per conversation; no work item is a valid state for informational intake |
| Batch | Frozen IDs, occurrence, route results/reasons, original conversation counts, progress | One active normal release per account; immutable membership once committed |
| Batch item | Unreviewed/Reviewed | Batch + conversation; links only that batch's exact messages |
| Account recovery | Normal/Recovering/Recovery blocked/Disconnected | Recovery prevents new release claims and cannot automatically return to interception |
| Send attempt | Draft/Pending/Confirmed/Failed/Unknown | Stable attempt identity; Unknown requires reconciliation before another attempt |

Gmail is authoritative for mail. The database is authoritative for workflow. Gmail labels are a recoverable projection; changing them externally cannot issue a workflow command. A projection failure leaves pending work visible and retriable, without rolling back a user's durable decision or claiming successful provider synchronization.

Original batch counts record distinct conversations at release, not changing thread size or current classification. Corrections update the current item while retaining its original route and counts for explanation. Review counts may decrease; a newly held arrival cannot increase them. A conversation in two batches has two review records. An action on one never silently reviews the other.

## Selected defaults and reasons

1. **Existing Inbox:** activation begins from a recorded synchronization boundary after reconciliation. Existing mail remains untouched and contributes no initial intake. Historical import is a separate opt-in operation. Mail near the activation boundary whose provenance is uncertain remains visible with an exception rather than silently archived.
2. **Waiting:** record a held human reply internally; reactivate visible work only when that reply is released. A supported bypass reply reactivates at synchronization and creates separately identified immediate intake, outside scheduled batches. Emergency peek changes neither Waiting nor review. This prevents the Desk from exposing held arrivals prematurely.
3. **Human reply versus prior decisions:** automatic bulk signals cannot prevent Waiting reactivation. A prior Aware decision cannot suppress a new external human reply to Waiting; the reply invalidates that stale decision for the new intake. Preserve an explicitly chosen horizon on an already Open item, including an overdue commitment. Reactivating Waiting uses a fresh This Week commitment because Waiting has no active horizon.
4. **Keep:** allowed only while effective classification is Aware. Explicit promotion or human-reply reactivation clears Keep, retaining its history for Undo where safe. Correcting an existing obligation to Aware explicitly resolves it and clears the horizon; the interface must explain that consequence before applying the user's correction.
5. **Sent-history coverage:** index at most the preceding 365 days of sent metadata at setup, then maintain incrementally. Display the coverage start and any incomplete scan; an address with no evidence falls through to Unsure, never presumed unknown forever. Normalize case and whitespace only; do not collapse dots or plus suffixes for arbitrary domains. Exclude the connected user's known sending/receiving identities from the human-correspondent heuristic. No Contacts scope.
6. **External edits:** respect externally visible mail; never re-hide a held message manually moved to Inbox. Reconcile it as an external release with immediate, separately identified intake and audit reason. Removal of Held without Inbox is a drift exception, not permission to archive or infer Done. Trash/Spam/deletion is an exception and is never automatically restored by normal release.
7. **Native unread:** preserve current Gmail read/unread during the initial feasibility experiments. Any change to that policy requires actual device evidence and an explicit product amendment. Workflow review stays independent under either policy.
8. **Partial release:** expose the frozen batch and truthful confirmed/pending/unavailable counts. Only confirmed released content is actionable; unresolved members remain visible as pending exceptions. Emit the single normal batch alert only after all selected mail is reconciled successfully. A partially failed or unavailable batch gets a health alert, not a misleading successful-delivery alert.
9. **Notification uncertainty:** reserve one durable alert attempt per nonempty batch. Retry only a confirmed rejection/non-delivery. An unknown transport result is recorded for reconciliation, with no blind retry unless the selected provider supports a verified idempotency key. This prefers a visible possibly-missed alert over duplicate interruption. Release never depends on notification success.
10. **Bypass feasibility:** supported rules must work at arrival. No polling-based release is presented as bypass. Conversation bypass remains gated until proven; an unsupported mechanism is surfaced as unavailable and cannot be activated. This is not an accepted removal of the specification's feature.

## Calendar contract

- Store an IANA timezone, enabled weekdays, local clock times and a schedule revision. Reject duplicate local windows. Preview upcoming exact dates, offsets and times before timezone/schedule changes are saved.
- A scheduled occurrence is identified by account, schedule revision, local date and configured window. Resolve it once to UTC and persist that instant. Workers retry that occurrence rather than generating a new batch identity.
- On a spring-forward gap, use the first valid instant after the missing local time on that date and display the adjustment. On a fall-back overlap, use the earlier occurrence once. These rules require timezone-library tests before scheduler implementation; no new dependency is selected here.
- Editing the schedule affects only future, unclaimed occurrences. An already claimed batch finishes under its original revision. Cancel unclaimed old-revision occurrences transactionally and show the next delivery; do not release mail merely because a setting changed.
- A missed occurrence remains overdue and visible. Once service recovers, resume its existing batch or create one catch-up batch for the oldest unhandled occurrence; mark other elapsed occurrences coalesced into it. Do not fire one notification for every missed window. The interface shows this catch-up decision and actual execution time. Recovery mode blocks automatic catch-up.
- Scheduled release and Check Now use the same account lock. A competing request returns the active batch. Check Now does not consume a future scheduled occurrence or change the schedule. Each manual request has a stable retry identity. An empty scheduled occurrence is recorded as completed with no alert.
- Today stores the selected local date and commitment timezone. This Week stores the Friday on/after that date; Saturday/Sunday select the following Friday. Overdue starts on the next local date, not after a rolling 24-hour interval. Whenever has no date. Timezone changes do not rewrite existing commitment dates/timezones; moving a horizon explicitly creates a new commitment. Waiting elapsed days use its recorded timezone and calendar-date difference.

## Primary transitions

Unless specified otherwise, these actions generate no notification. Provider effects are durable, exact-message projections with reconciliation after uncertain outcomes. User actions use a command ID and expected revision; replay returns the existing result. Undo is a new audited command and fails visibly if intervening work makes restoring the old state unsafe.

| Action | Before and guard | After | Gmail effect | Failure / Undo |
|---|---|---|---|---|
| Connect / reconnect | Allowed identity and valid consent; pinned account | Encrypted credentials; connection verified separately; interception remains off | Identity/profile reads | Invalid consent changes no mail; reconnection cannot activate interception |
| Activate | Setup, recovery rehearsal and live gates passed; explicit activation | Record baseline and app-owned resource IDs, then active interception | Only proven app-owned rules/labels | Verify cleanup on partial failure; unresolved filter cleanup is critical |
| Ordinary arrival | Activated scope; no explicit bypass | Held, absent from active intake | Proven interception adds Held and skips Inbox | Drift/coverage failure is critical; never invent a Held success |
| Bypass arrival | Explicit enabled rule with proven mechanism | Bypassed, attributed immediate intake; never scheduled membership | Ordinary Gmail delivery | No synthesized bypass from heuristics; record native alerts separately |
| Freeze scheduled / manual release | Normal account; account lock; unassigned held IDs | Immutable batch and routes with pending per-message outcomes; atomic job enqueue | None at freeze | Rollback leaves no orphan; retries use same IDs |
| Apply / reconcile release | Exact snapshot member; still eligible; recovery has not taken control | Confirmed Released only after provider state verified; new batch item unreviewed | Remove Held; Aware outside Inbox; Needs You/Unsure in Inbox for fallback | Lost response is unknown until read-back; no thread-wide mutation; Trash/Spam/deleted becomes exception |
| Complete release | Every selected outcome confirmed; none pending/unavailable | Completed; original conversation counts fixed | None beyond reconciled projection | Nonempty batch requests one alert under policy above; incomplete batch cannot claim success |
| Open Letter / emergency peek / Open in Gmail | Accessible source; held content only in deliberate peek | No app review or work change | Opening app view/peek does not mark Gmail read; external Gmail may alter its own read state | Opening failure shows unavailable source; peek use recorded |
| Aware Next | Current Aware batch item unreviewed and released | That item Reviewed; no work created | Clear Review only for processed message IDs; retain Aware/source | No deletion; safe Undo restores review |
| Aware Keep / remove Keep | Effective Aware | Keep adds Reviewed on current intake; removal changes only Keep | Project Keep; source remains | Safe Undo restores prior flag/review |
| Aware Skip | Unreviewed item | Session order only; still Unreviewed | None | All-skipped remainder still blocks Caught Up |
| Promote / Unsure → Needs You | Explicit classification choice | Needs You; Open This Week if no Open commitment; current item Reviewed; clear Keep | NeedsYou/horizon projection, remove Inbox for acknowledged IDs | Undo restores prior workflow only at matching revision |
| Unsure → Aware / explicit correction to Aware | Explicit informed choice, including resolution of any obligation | Aware; current item Reviewed; existing work Resolved without horizon; optional Keep | Aware projection, remove Inbox for acknowledged IDs | Preserve decision history; no automatic demotion allowed |
| Acknowledge / select horizon | Open Needs You; explicit action | Current item Reviewed; preserve or explicitly replace horizon | Remove Inbox/Review on processed released IDs; project horizon | Merely opening Letter does not qualify |
| Done | Explicit action on current work | Resolved, horizon cleared; current intake Reviewed | Remove Inbox/Review and active work labels on processed IDs | Does not review another batch; safe Undo supported |
| Waiting | Explicit action or chosen disposition after confirmed send | Waiting, horizon cleared, waiting start recorded; current intake Reviewed | Waiting projection; remove Inbox/Review on processed IDs | No implicit Waiting on failed or unknown send |
| Reopen / Keep Open | Explicit action, or confirmed-send disposition | Open; retain existing commitment or default This Week | Project work/horizon; do not reinsert reviewed mail into Inbox | Current-intake review only when explicitly acknowledged |
| Receive human reply to Waiting | New external human message, not self/automated; delivery visibility guard | At release/bypass: Needs You, Open This Week, new Unreviewed intake | Normal release projection; prior batches unchanged | Held arrival alone does not change visible Desk; repeats deduplicated by message ID |
| Receive automated reply / bounce | Deterministic automation evidence | Route new intake normally; retain Waiting obligation | Normal delivery projection | Ambiguous automation becomes Unsure for review; cannot silently close Waiting |
| Automatic routing / new reply on Open | First-match routing then conversation aggregation | Needs You > Unsure > Aware; retain existing Open obligation/horizon | Classification projection for released IDs | Never demote obligation automatically; explicit correction remains available |
| Receive message on Resolved | New released message | New intake; Needs You opens fresh This Week work; Aware leaves no obligation; Unsure waits for choice | Normal projection | Historical resolved work remains in audit; at most one current work item |
| Correct route / save rule | Explicit current-item correction; persistent scope opt-in | Current classification changes; optional rule for future routing | Current projection only | Deleting rule does not rewrite history; Undo removes newly created rule only if unchanged |
| Draft / send | Valid recipient/content; authorized send capability; stable attempt | Pending then Confirmed/Failed/Unknown; preserve draft on failure/unknown | One send attempt | No automatic retry after unknown; no work disposition before confirmed success |
| Post-send disposition | Confirmed associated send | User chooses Done/Waiting/Keep Open; standalone send creates no work unless Expect a reply | Sent source preserved; project chosen work state | Dismissed prompt leaves prior work unchanged; do not guess intent |
| External sent reply | New sent ID linked to Open work | Visible disposition prompt, unchanged work until choice | Read/reconcile only | Deduplicate prompt; do not infer Done from SENT |
| External read / archive / app-label edit | Provider change observed | Update source/projection drift only; no workflow command | Respect source; never repair by re-hiding external Inbox delivery | Show actionable drift; no implicit review/Done |
| Held moved to Inbox externally | Confirmed external Inbox presence | External release with separately identified immediate intake | Do not remove Inbox to enforce holding | In a pending batch reconcile the same message once; never duplicate intake |
| Source deleted / trashed / spam / inaccessible | Provider evidence, distinguished from transient outage | Visible unavailable exception; retain unresolved work/review history | No automatic resurrection or deletion | Owner may explicitly dismiss intake exception (reviewed), leaving work resolution a separate decision |
| Panic | Any connected state; acquire recovery ownership, stop conflicting claims | Recovering; interception disabled/verified before restore; expose residual counts | Disable only owned filters, then restore eligible held messages to Inbox regardless of routing | Reconcile in-flight calls; re-scan until stable; blocked auth shows direct Gmail card; never auto-reactivate |
| Disconnect | Recovery sequence completed and verified, no trapped mail | Offer metadata export; revoke; Disconnected | Restore before revoke; explain retained labels | Failure retains recovery capability; residual-risk override requires a specific informed user choice |
| Sign out | Browser session exists | Browser session ended only | None | Does not revoke Google access or change mailbox automation |
| Restore database | Isolated environment; jobs and Gmail access disabled before startup | Quarantine stale attempts; reconcile before any explicit enablement | No Gmail effects at startup | Missing keys or reconciliation failure blocks enablement; pending sends never replay blindly |

## Forbidden states and concurrency rules

- Hold policy pairs only with Held or Released; Bypass pairs only with Bypassed. Bypassed mail cannot be a scheduled snapshot member.
- Open requires exactly one horizon; dated horizons require date/timezone, Whenever has no due date. Waiting and Resolved have no active horizon. Aware cannot retain an Open obligation or Keep after becoming Needs You/Unsure.
- Review belongs to an intake occurrence, not a permanent conversation flag. Unreviewed items cannot be hidden just because work is Waiting/Resolved or Gmail is archived/read.
- Caught Up means **zero unreviewed released intake across all batches and immediate intake**. Pending release errors remain a separate visible health state; Caught Up cannot imply delivery is healthy. Open and Waiting work do not block it.
- No new arrival changes snapshot membership, original route evidence or counts. A message belongs to at most one normal release. Multi-message conversations are grouped only over exact selected IDs.
- Persist workflow command and outbound projection intent atomically. Never hold a database transaction open around Gmail calls. Use durable ownership/revisions, not an in-process mutex, for claims.
- Recovery invalidates new normal release claims. It must also account for calls already in flight: quiesce/reconcile them and verify restoration after they settle. A database lease alone does not fence an already-sent Gmail HTTP request.
- A batch with pending, unknown or unavailable members cannot be marked fully released. Missing source is not confirmed delivery. Failed/unknown sends cannot apply dispositions.
- Replaying a command cannot create a second work item, release, notification attempt or external-send prompt. Undo cannot erase later human decisions or undo a successful send.

## Required examples for implementation tests

1. Review batch A for a conversation, receive a held reply, then release batch B: B is unreviewed and A unchanged.
2. Waiting + held human reply + emergency peek: still Waiting; release reopens This Week; duplicate synchronization does not reopen twice.
3. Open Today + bulk Aware arrival: obligation/date preserved. Explicit Aware correction resolves it; stale Undo is rejected.
4. All Pile items skipped: not Caught Up. All intake reviewed with Open Whenever and Waiting items: Caught Up.
5. Freeze IDs A/B; C arrives; A succeeds, B response lost: retry reconciles A/B only, C stays held, no normal alert until completion.
6. Recovery begins while a Gmail call is in flight: stop new claims, disable interception, reconcile that call, restore, verify; restart cannot reactivate.
7. External archive/read leaves work unchanged; externally restored held Inbox mail is not hidden again; Trash during release is not resurrected.
8. Failed/unknown send preserves draft and obligation; confirmed send with no disposition leaves a visible prompt.
9. Saturday This Week selects next Friday; Friday remains that day; Today becomes overdue at local midnight. DST gap/overlap and timezone edits follow the rules above.
10. Two workers / Check Now / repeated occurrence produce one batch; notification uncertainty cannot create duplicate alerts.

These are acceptance examples, not claims that a production workflow engine exists. The next implementation uses them as behavioral tests while the live Gmail matrices remain open.
