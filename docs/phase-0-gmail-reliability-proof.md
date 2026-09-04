# Phase 0: Product contract and Gmail reliability proof

Date: 2026-09-04

Status: In progress. The [local foundation and synthetic persistence probe](evidence/phase-0/2026-09-04-foundation.md) have passed their checks. The [read-only Google connection](evidence/phase-0/2026-09-04-google-connection.md) also passes local automated checks; owner consent and the live profile check remain pending. No real Gmail, device, external-alert, or restore experiment has passed yet.

This expands Phase 0 of the [product specification](email-client-product-implementation-spec.md) using [ADR-0001](decisions/0001-application-architecture.md). It authorizes a small feasibility implementation when implementation begins, not the full Room. The owner has explicitly authorized a read-only connection for the selected Gmail account. This does not authorize interception, sending, or full personal-mail dogfooding; later security and operational gates still apply.

## Objective and sequence

Prove arrival interception and recovery first, finite delivery second, and the state contract before building the full interface. Use a dedicated Gmail test mailbox and controlled sender accounts. Build only the tools needed to observe and exercise these behaviors: account connection, diagnostic state, batch/recovery controls, and an evidence recorder.

| Step | Deliverable | Verification |
|---|---|---|
| 1 | State contract and decision register | Every action has defined before/after state; unresolved semantics are visible |
| 2 | Isolated test setup and OAuth inventory | Correct identity/scopes; only the owner-authorized account; direct Gmail access works |
| 3 | Interception and notification matrix | Provider state plus actual device observations for each fixture |
| 4 | Durable batch prototype | Crash, retry, and concurrency tests preserve exact membership |
| 5 | Recovery and independent alerting | Panic, direct Gmail recovery, disconnect, and full Render outage rehearsals |
| 6 | Restore rehearsal and evidence review | Safe restored state, no unintended Gmail writes, all exit gates supported |

No deployment, account provisioning, or Gmail mutation is performed by creating this plan.

## 1. Freeze the behavioral contract

Produce a transition table or executable domain tests covering every primary journey in specification sections 7–11. Each row needs action, before-state, guard, after-state, Gmail effect, notification effect, and failure/undo behavior. Include forbidden combinations and account-level concurrency rules.

Carry forward these settled invariants:

- Delivery policy/state, classification, batch review, work status, horizon, and Keep remain independent.
- A frozen batch stores exact message membership; later arrivals cannot enter it.
- Caught Up concerns released intake; Open and Waiting work may remain.
- Waiting and Resolved have no active horizon. Failed sends cannot change work status.
- Explicit user rules have the specified precedence over deterministic heuristics.
- Panic and manual recovery disable interception before restoring held mail.

Resolve and record these before the exit gate; recommendations below are not silently accepted product amendments:

| Question | Proposed starting point / required proof |
|---|---|
| Waiting reply visibility | Record arrival internally, but expose reactivation when the held reply is released; confirm handling for bypass and emergency peek |
| Existing Inbox at onboarding | Leave existing Inbox mail untouched unless the user explicitly chooses an import; define initial intake and counts |
| Historical sent-address heuristic | Choose a bounded history policy and explain incomplete coverage; verify aliases/self-mail exclusions |
| Conversation bypass | Prove an arrival-time mechanism; if unsupported, explicitly amend the feature contract instead of presenting delayed release as equivalent |
| Gmail external edits | Define read/archive/delete/move effects, including a held message manually moved to Inbox and deletion during release |
| Daylight saving and schedule edits | Define skipped/repeated clock times, occurrence identity, overdue windows, timezone changes, and Check Now races |
| Partial batch alert | Define when the single app alert is attempted and how ambiguous notification outcomes avoid duplicates |
| Recovery and visibility | Define what interrupted releases and partially recovered messages show, without hiding unresolved mail |

## 2. Test setup and authorization

Record environment name, application revision, database version, OAuth client mode/scopes, Gmail account type, receiving identities, existing filters, category settings, device/OS/app versions, and notification settings. Keep credentials and message content out of committed evidence.

Prepare primary-address, alias, plus-address, forwarding, Bcc, list, automated reply, calendar invitation, authentication-code, attachment, and existing-thread fixtures. Record unsupported account features explicitly; do not pass untested identities by assumption.

Inventory each Gmail method and its required scope. Test denied consent, wrong identity, token refresh, revoked access, and reauthorization without duplicate filters or lost recovery metadata. Prove interception can be disabled with the granted access.

Google documents seven-day refresh-token expiration for External applications in Testing, with limited basic-profile exceptions. Gmail authorization must have a documented lifecycle compatible with the later two-week dogfood; moving to another publishing mode does not make tokens permanent. [Google OAuth token expiration](https://developers.google.com/identity/protocols/oauth2#expiration)

Deliver an offline recovery card before enabling any interception, even on the test account. The owner must be able to open Gmail without the application.

## 3. Interception, bypass, and device matrix

For each applicable fixture above, inspect message-level label IDs before and after release. Test new messages and new replies in existing threads. Repeat with existing filters enabled, category routing, and multiple incoming messages close together.

| Experiment | Pass criteria |
|---|---|
| Normal arrival | Intended mail is held at arrival, remains directly discoverable in Gmail, and is absent from Inbox until release |
| Explicit bypass | Each supported rule bypasses at arrival with its promised notification behavior; overlapping filters cannot silently defeat it |
| Mixed thread | New held reply does not become visible/released merely because an older thread message was released |
| New arrival during release | Its message ID stays outside the frozen batch and remains held unless an explicit bypass applies |
| Existing filters | Conflicts are detected or documented with an actionable supported configuration |
| Spam/Trash and unusual mail | No silent loss and no automatic resurrection from Spam/Trash; behavior and exclusions are recorded |
| Interception removed or altered | Health check detects drift; behavior does not silently diverge from the UI |

For each actual device used by the owner, observe held arrival, bypass, single-message release, multi-message release, and an arrival during release. Record banners, sounds, unread badges, category effects, and delayed Inbox notifications. Screenshots must use synthetic content.

Do not assume Gmail emits one batch notification. Select a product notification mechanism based on device results. Its failure must not block mail release; tests must demonstrate at most one app batch alert under retries and uncertain delivery. Record any native Gmail alerts separately and obtain acceptance of remaining device limitations before exit.

## 4. Finite delivery and concurrency proof

Use at least two independently executing workers, not only an in-process lock. For a known fixture set, persist membership and compare it with Gmail message-level state after every experiment.

| Fault or race | Required result |
|---|---|
| Two scheduled executions; scheduled versus Check Now | One coherent active release per account, no duplicate selected items or drifting membership |
| Crash before commit/enqueue | No orphaned domain transition; transaction rollback or outbox recovery proven |
| Crash after snapshot, before Gmail call | Same batch resumes with the same IDs |
| Gmail succeeds, response is lost, worker crashes | Reconcile actual labels and converge without widening selection |
| Partial success / rate limit / provider outage | Per-message progress persists; bounded retries and unresolved counts are visible |
| New reply arrives during retry | It remains outside the original batch |
| Empty window, overdue window, DST transition | Defined contract is followed with stable occurrence identity |
| Panic or disconnect races with release | Recovery prevents conflicting work and cannot re-enable interception accidentally |
| Expired history cursor / concurrent arrivals during resync | Full synchronization converges without lost changes or corrupting frozen batches |

Sending remains outside the full Phase 0 prototype. Capture its unknown-outcome/no-blind-retry contract in the transition artifact and restore tests; implement and test real sending in the specification's compose phase using controlled recipients.

## 5. Failure detection and recovery proof

Initial strategy: independent Better Stack alerts plus tested panic and direct Gmail recovery. Do not claim automatic fail-open behavior.

Proposed monitor cadences must be selected so combined polling and grace deliver an alert by 15 minutes after an unresolved expected release. A successful generic heartbeat must not conceal a failed mailbox operation. Prime monitors and deliver a test notification through the selected independent channel.

| Failure | Required evidence |
|---|---|
| Web healthy but worker stopped | Missed work detected; independent alert received within deadline |
| Scheduler runs but Gmail sync/release fails | Semantic health goes critical even though processes remain alive |
| All Render services unavailable | External missing-heartbeat/uptime alert arrives; Gmail recovery card works without Render |
| OAuth revoked while interception exists | Clear critical state; direct Gmail recovery succeeds without API credentials |
| Database unavailable | No false success; independent alert and manual recovery remain usable |
| Backup upload fails or backup runner stops | No success heartbeat; independent missed-backup alert arrives |
| Recovery partially fails | Released/failed/still-held counts remain accurate; re-running completes safely |

Panic rehearsal: stop conflicting work; disable and verify removal of app-owned interception; discover held messages with pagination; restore them with tracked outcomes; verify none remain unintentionally held; send another fixture to demonstrate ordinary future Inbox delivery. Repeat panic and check idempotence.

Manual rehearsal, with the app unavailable: open Gmail; disable/delete the identified app-owned interception filter(s); select all held mail across pages and restore Inbox; verify residual held mail and new ordinary delivery. Validate exact Gmail UI instructions on the actual account. Do not delete unrelated filters or treat a stale Held label count as proof of success.

Disconnect rehearsal: pause release, disable interception, restore and verify, offer metadata export, then revoke access. Failure before verification must retain the ability to recover and clearly expose residual risk.

## 6. Backup and restore proof

Create synthetic rules, windows, workflow states, local drafts, and batches with known checksums/identifiers. Take a Render recovery point and a separate encrypted R2 export. Then change Gmail and database state so restored jobs are stale relative to Gmail.

Restore each path into an isolated database with Gmail writes and all job execution disabled before application startup. Verify decryption using separately stored keys, schema compatibility, expected records, and known losses since the backup. Quarantine pending send/release operations, reconcile Gmail, and demonstrate that merely starting the restored app cannot send or release mail.

Record elapsed recovery time, recovery-point age, manual steps, and unresolved records. Confirm the proposed 24-hour independent-export recovery point and measured recovery time are acceptable before personal dogfood. Test missing/corrupt objects and missing-key handling without claiming a successful restore.

## Evidence format

For each experiment, record:

- ID, date, operator, application revision, environment, and sanitized fixture IDs.
- Preconditions, exact action/fault, expected result, and observed result.
- Relevant sanitized state snapshots, device observations, alert receipt times, or logs.
- Pass / Fail / Blocked / Not applicable, with justification; link defects and the successful rerun.

Store results under `docs/evidence/phase-0/` when experiments begin. Do not create placeholder passes. Store secret-bearing artifacts outside the repository; link only sanitized records. A claimed provider limitation must include observed evidence and its product consequence.

## Exit checklist

All entries start unchecked. A plan is not evidence.

- [ ] State-transition contract completed; open product decisions resolved and specification amended where needed.
- [ ] Identity/scope inventory and authorization lifecycle documented and tested.
- [ ] Every intended receiving identity and bypass rule passes or has an explicitly accepted scope change.
- [ ] Device notifications and badge behavior observed; app batch-notification behavior chosen and proven.
- [ ] Frozen membership, retries, multiple workers, and partial failures pass.
- [ ] History recovery and external Gmail changes preserve the agreed contract.
- [ ] Independent alerts received during both partial failure and total Render outage within the required deadline.
- [ ] Panic, manual recovery, and safe disconnect pass on the real test account, including repetition and new mail afterward.
- [ ] Render and R2 restores verified with side effects disabled; recovery point/time and key custody documented.
- [ ] Telemetry redaction checked with sensitive synthetic fixtures.
- [ ] Evidence reviewed with the owner; no unexplained critical gap remains.

If an essential interception or recovery assumption fails, stop advancement to the Room and revise the product contract. Phase 0 completion permits the subsequent implementation phases; the personal mailbox remains behind their separate readiness gates.
