# Project progress

Last updated: 2026-09-05 UTC (live interrupted hold recovery completed at 12:42 UTC)

This is the current status and next-action tracker. **Resuming in another app:**
read the
[exe.dev deployment and session handoff](docs/exe-deployment-handoff.md) for
host/access details, deployment commands, secret locations, rollback boundaries
and the exact stopping point. The
[product specification](docs/email-client-product-implementation-spec.md#26-phased-implementation-plan)
defines scope and acceptance criteria; the
[Phase 0 proof plan](docs/phase-0-gmail-reliability-proof.md) defines the
detailed experiments. Evidence documents are dated records, not the current work
queue.

## Current position

**Phase 0 is in progress; its exit gate has not passed.** The authenticated app
previews five Inbox messages and now implements single-message and fixed
three-message controlled hold/release with durable recovery. Automatic
interception, continuous sync and sending remain disabled. Hosted read-only
sign-in and preview have live evidence; the controlled app hold/release now also
has live provider evidence, including recovery after a web restart.

**Current status:** the interrupted three-message hold rehearsal passed. SSH
access works again. The same three saved members are released at repeat revision
three, all unread in Inbox, with zero pending/errors and no pending disconnect.
The newcomer remains outside membership with unchanged labels. Temporary
diagnostics were removed and web restarted; readiness and cleanup passed.

**Latest verified result:** after Google accepted the second hold and the request
was killed, durable pending intent survived a web restart. Guarded recovery
modified only the third member, verified all three held/unread, then ordinary
release returned all three to Inbox. [Hold recovery evidence](docs/evidence/phase-0/2026-09-05-live-hold-recovery.md).
The earlier [arrival evidence](docs/evidence/phase-0/2026-09-05-live-arrival-recovery.md)
proved that a new arrival during interrupted release stays outside membership.

**Latest implemented slice:** revision-guarded repeat of the same frozen batch,
deployed at `ed8756f`. Every member is verified released before new hold intent;
stale forms cannot re-hold mail after a subsequent release. No recovery record
is reset. All 138 backend and 23 browser tests passed, plus TypeScript,
compilation and formatting checks. Earlier
[batch crash](docs/evidence/phase-0/2026-09-05-live-batch-recovery.md) and
[revocation crash](docs/evidence/phase-0/2026-09-05-live-revoke-recovery.md)
proof remains valid.

## Next action

Continue the broader Phase 0 arrival/interception and existing-filter cases,
with explicit bounded fixtures and evidence before enabling automatic behavior.
Interrupted fixed-batch hold and release now have live restart/recovery proof;
continuously executing worker races remain unproven. Independent alerts and
actual-device notification proof remain open. Use explicit revision-guarded
repeat controls; do not reset durable records or repeat the superseded manual
Gmail filter exercise. No owner authentication or send action is pending.

The owner uses the Gmail app on iPhone and reports all Gmail notifications,
sounds and badges disabled. Batch notifications are optional and off by default
by owner decision; this preference is documented, not yet an implemented
settings feature. Independent alert setup and the broader interception/device
matrix remain open; accepted-token-revocation crash recovery now passed. The
owner has authorized implementation, verification, pushing to main and
deployment to the existing exe.dev VM. Group human Google instructions into one
manageable batch.

The owner waived manual export of disposable test mail. Product-wide recovery
requirements remain in force. Native notification proof needs actual owner
devices, and full Phase 0 acceptance still needs empirical evidence.

Render provisioning is superseded by the dedicated exe.dev VM. Daily encrypted
same-VM backups are enabled with 14-copy retention, a successful independent
restore and a verified first unattended scheduled run;
[runbook](docs/vm-backups.md),
[evidence](docs/evidence/phase-0/2026-09-05-vm-backups.md). The owner deferred
external storage for now. Hosted alert receipt, independently scheduled off-VM
backups and total-VM-loss recovery still need evidence. Full Room, production
mail mutations and personal dogfood remain gated on Phase 0 results.

Autonomous work, verified commits and regular pushes remain authorized. Resume
independent work when new information or the live results establish the next
supported implementation step; no routine reapproval is needed.

## Completed work and evidence

| Work                                               | Status                                    | Evidence and limits                                                                                                                                                                                                                                                                                                                            |
| -------------------------------------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Architecture choice                                | Decided                                   | [ADR-0001](docs/decisions/0001-application-architecture.md): Elixir/Phoenix/Ash, React/Inertia, PostgreSQL/Oban, R2, Sentry and Better Stack; [ADR-0002](docs/decisions/0002-exe-vm-hosting.md) replaces Render with exe.dev. Choosing a service does not mean it is configured.                                                               |
| Compatible dependency baseline and local app       | Verified locally                          | [Foundation evidence](docs/evidence/phase-0/2026-09-04-foundation.md), [versions](docs/dependency-versions.md). Local build/release, database readiness, browser navigation.                                                                                                                                                                   |
| Immutable snapshots and atomic job enqueue         | Verified with synthetic data              | Foundation evidence: concurrency, rollback, membership invariants, duplicate execution and separate worker. This synthetic scheduler is not wired to Gmail; separate controlled Gmail release now has live proof below.                                                                                                                        |
| Restricted Google OAuth and encrypted credentials  | Implemented; live sign-in verified        | [Connection evidence](docs/evidence/phase-0/2026-09-04-google-connection.md). Tests cover state/nonce/PKCE, signed identity, allowed account, replay and session controls.                                                                                                                                                                     |
| Gmail profile check                                | Verified live                             | Owner completed sign-in; browser and database showed successful verification.                                                                                                                                                                                                                                                                  |
| Automatic token refresh                            | Verified live with simulated local expiry | Connection evidence: real Google refresh and profile check, same browser session, valid future expiry, released lease. Natural expiry and provider refresh-token rotation remain unproven.                                                                                                                                                     |
| Revocation detection and reconnection              | Owner-reported live pass                  | Owner removed the Google grant, observed the reconnect message, reauthorized, and reported “connection verified.” This did not exercise held-mail recovery.                                                                                                                                                                                    |
| Five-message Inbox metadata preview                | Implemented and verified live             | [Listing evidence](docs/evidence/phase-0/2026-09-04-read-only-message-list.md). No bodies/attachments, database persistence of email metadata, or Gmail mutations.                                                                                                                                                                             |
| Desk-inspired preview design                       | Implemented and visually verified         | [Design evidence](docs/evidence/phase-0/2026-09-04-desk-preview-design.md): local Newsreader, responsive whitespace-led layout, light/dark themes, connection disclosure and interaction states. Full Room design implementation remains later work.                                                                                           |
| Written state contract                             | Complete as documentation                 | [Contract](docs/phase-0-state-contract.md); runtime and live-provider proof remain separate.                                                                                                                                                                                                                                                   |
| Render release and restore startup                 | Verified locally; not deployed            | [Evidence](docs/evidence/phase-0/2026-09-04-render-preparation.md), [setup](docs/render-phase-0-setup.md). Retained as an unused alternative after the exe.dev decision.                                                                                                                                                                       |
| Recovery card and experiment inventory             | One-fixture direct recovery rehearsed     | [Card](docs/phase-0-offline-recovery-card.md), [inventory](docs/phase-0-experiment-inventory.md), [live evidence](docs/evidence/phase-0/2026-09-05-independent-recovery.md). Direct Gmail recovery passed with web/worker stopped; private offline copy exists. Multi-page, revoked-access and device proof remain open.                       |
| Per-message release journal                        | Verified with synthetic outcomes          | [Evidence](docs/evidence/phase-0/2026-09-04-release-journal.md); live provider integration remains open.                                                                                                                                                                                                                                       |
| Executable work-item contract                      | Verified locally                          | [Evidence](docs/evidence/phase-0/2026-09-04-workflow-contract.md); calendar dates, Waiting visibility and confirmed-send guards. Not a persisted workflow engine.                                                                                                                                                                              |
| Account recovery fence                             | Verified with synthetic accounts          | [Evidence](docs/evidence/phase-0/2026-09-04-recovery-fence.md); database serialization and in-flight accounting for the synthetic model. The controlled Gmail flow separately has live restore-before-revoke proof below.                                                                                                                      |
| Finite batch review                                | Verified with synthetic outcomes          | [Evidence](docs/evidence/phase-0/2026-09-04-batch-review.md); separate per-batch review and pending-delivery status, no UI integration.                                                                                                                                                                                                        |
| Local occurrence resolution                        | Verified with IANA data                   | [Evidence](docs/evidence/phase-0/2026-09-04-delivery-occurrences.md); DST gaps/overlaps, stable identity and explicit date exceptions. Durable scheduling exists as a local probe below; production calendar and timer/Gmail integration remain unimplemented.                                                                                 |
| Durable scheduling probe                           | Verified locally                          | [Evidence](docs/evidence/phase-0/2026-09-04-durable-scheduling.md); saved occurrences, coalescing, revision edits, manual receipts and account serialization. No timer/Gmail integration.                                                                                                                                                      |
| Encrypted local backup and restore                 | Verified on disposable databases          | [Evidence](docs/evidence/phase-0/2026-09-04-local-backup-restore.md); actual pg_dump/age/pg_restore, corruption/key checks, inert restored jobs. No R2/Render proof.                                                                                                                                                                           |
| Read-only identity/filter inventory                | Tested locally and verified live          | [Implementation evidence](docs/evidence/phase-0/2026-09-04-read-only-inventory.md), [hosted inventory](docs/evidence/phase-0/2026-09-04-hosted-oauth-setup.md): one matching primary identity, 15 labels and three existing filters at inventory time. Filter compatibility and receiving-alias support remain unproven.                       |
| Primary-address ordinary arrival                   | Owner-reported live baseline              | [Evidence](docs/evidence/phase-0/2026-09-04-primary-arrival-baseline.md); synthetic message visible in Inbox through direct Gmail access. Automatic interception remains untested; later controlled recovery has separate evidence below.                                                                                                      |
| Dedicated exe.dev deployment                       | Live controlled prototype deployed        | [Initial evidence](docs/evidence/phase-0/2026-09-04-exe-deployment.md), [current release](docs/evidence/phase-0/2026-09-05-held-batch-disconnect.md): Linux build, migrations, healthy web, separate worker, hosted OAuth and controlled Gmail recovery. Same-VM backups are scheduled; R2 and independent outage alerts remain open/deferred. |
| Hosted read-only OAuth configuration               | Live sign-in/profile/preview verified     | [Evidence](docs/evidence/phase-0/2026-09-04-hosted-oauth-setup.md): separate client/keys, web-only read-only mounts, corrected production compile setting and live inventory (three existing filters).                                                                                                                                         |
| Controlled Gmail hold/release and guarded repeats  | Verified live for one and three messages  | [Batch crash evidence](docs/evidence/phase-0/2026-09-05-live-batch-recovery.md), [repeat implementation](docs/evidence/phase-0/2026-09-05-held-batch-disconnect.md). Fixed saved membership, partial release recovery across restart and no duplicate writes. Arrival during interrupted release and [interrupted hold recovery](docs/evidence/phase-0/2026-09-05-live-hold-recovery.md) passed; recovery wrote only the unresolved third member.               |
| Controlled safe disconnect and revocation recovery | Verified live within fixture scope        | [Held-batch restoration](docs/evidence/phase-0/2026-09-05-held-batch-disconnect.md), [revocation crash recovery](docs/evidence/phase-0/2026-09-05-live-revoke-recovery.md). Restore/verify before revoke, cleanup and reconnect passed; general interception recovery remains open.                                                            |
| Scheduled same-VM encrypted backups                | Enabled; first unattended run verified    | [Evidence](docs/evidence/phase-0/2026-09-05-vm-backups.md). Retain 14 successful copies; an actual archive restored independently on the owner Mac. R2/off-VM scheduling and independent failure alerts remain deferred/unconfigured.                                                                                                          |
| Shared progress tracking                           | Complete                                  | This document is linked from README and the Phase 0 plan.                                                                                                                                                                                                                                                                                      |

## Phase 0 work remaining

Checked items require their stated evidence; implementation alone does not pass
a proof gate.

- [x] **0.1 — Written state and workflow contract:**
      [transition table and decisions](docs/phase-0-state-contract.md), with
      illegal states, calendar semantics and acceptance examples. Runtime
      implementation and provider experiments are separate gates; the static app
      page is not the full contract.
- [ ] **Test environment:** [exe.dev setup](docs/exe-phase-0-setup.md) passed
      initial synthetic hosted checks; owner browser access is
      screenshot-confirmed; hosted sign-in/profile/preview and read-only
      inventory passed. Configured identities and single/three-message fixtures
      were validated in live rehearsals; the existing-filter inventory and
      owner-reported iPhone settings are recorded. Remaining work: filter
      compatibility, broader fixture coverage and measured device behavior
      before automatic interception.
- [x] **Provider error classification:** disabled API, insufficient scope and
      other permission errors are distinct; covered by automated tests in the
      controlled-flow slice.
- [ ] **Authorization lifecycle:**
      [method/scope inventory](docs/phase-0-experiment-inventory.md) prepared;
      controlled Gmail modification consent, revoke/reconnect and
      accepted-revocation crash recovery have live proof. Settle the dogfood
      authorization strategy and verify natural token expiry and refresh-token
      rotation. Inventory any further scopes before expanding the controlled
      boundary.
- [ ] **0.2 — Interception matrix:** prove primary address, aliases, forwarding,
      Bcc, lists, existing threads, unusual mail and filter conflicts; document
      unsupported cases.
- [ ] **0.3 — Notification/badge matrix:** observe held arrival, bypass and
      release on actual devices. The owner chose optional batch alerts, off by
      default with an on/off toggle; implementation and device proof remain
      open.
- [ ] **Real finite release:** implement per-message progress and prove fixed
      membership through retries, partial success, lost responses, worker
      crashes and concurrent arrivals. The
      [synthetic journal](docs/evidence/phase-0/2026-09-04-release-journal.md)
      now covers claims, partial outcomes and stale workers; synthetic account
      recovery races now pass; single-fixture live Gmail hold/release crash
      recovery now passed; the fixed three-message implementation now passes
      automated partial/crash recovery and disconnect tests; live three-message
      interrupted hold and release recovery now passed, including a new arrival
      between interrupted release and recovery; continuously executing worker
      races and broader provider recovery races remain unproven.
- [ ] **0.4 — Panic and direct Gmail recovery:**
      [offline recovery card](docs/phase-0-offline-recovery-card.md) now
      includes rehearsed one-fixture direct Gmail recovery with web/worker
      stopped and a private offline copy. General interception, all-page,
      revoked-access and new-arrival proof remain open.
- [ ] **Safe disconnect:** the
      [controlled flow](docs/phase-0-safe-disconnect.md) implements
      restore/verify before revoke with durable retries; live restoration from
      held, accepted revocation, cleanup and reconnect passed for the single
      fixture; single-message hold/release crash recovery passed;
      accepted-revocation request crash/restart/retry now passed without further
      mail operations; held-batch restore-before-revoke now passed live; future
      general interception recovery remains unproven. Browser sign-out remains
      separate.
- [ ] **Independent monitoring:** configure Sentry and Better Stack with
      redaction; test meaningful failed-work and missed-heartbeat alerts,
      including total VM outage.
- [ ] **Backups and restore:** one-off encrypted hosted export restored
      successfully on the owner Mac with stale held metadata, Gmail disabled and
      no Oban process; same-VM daily encrypted exports with 14-copy retention
      are enabled, an archive is restore-tested, and the first unattended
      scheduled run passed; independently scheduled off-VM exports and R2 copies
      remain deferred; restore both into isolated environments with Gmail
      writes/jobs disabled and verify reconciliation and measured
      losses/recovery time.
- [ ] **Exit review:** review the recorded evidence and explicitly accept
      provider/device limitations and state semantics. Only then move to full
      product implementation.

### Remaining external decisions and proof

| Decision                                                                   | Needed before                                                         |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Arrival-time bypass support, including conversation rules                  | Live interception experiment; no unsupported promise may be activated |
| Native read/unread and device notifications                                | Actual device matrix before policy changes                            |
| Independent alert destination and off-VM backup retention/key custody      | Operational proof before dogfood                                      |
| Retention, recovery-key custody and acceptable measured recovery loss/time | Backup/restore acceptance and dogfood                                 |

The state contract resolves implementation semantics under the autonomous-work
instruction. Live-provider limitations and operational acceptance still require
evidence; older recommendations in the proof plan are superseded only by the
explicitly recorded contract defaults.

## Full product roadmap

| Phase                                            | Status                                                          | What remains / completion reference                                                                                                                                                                                                  |
| ------------------------------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **0 — Product contract and Gmail feasibility**   | In progress                                                     | Checklist above; individual proofs have passed, but the overall Phase 0 exit gate remains open.                                                                                                                                      |
| **1 — Safe account connection and interception** | Not complete; connection groundwork exists                      | Production-ready identity/onboarding, app-owned Gmail resources, safety rehearsal, health, panic and safe disconnect. [Phase 1](docs/email-client-product-implementation-spec.md#phase-1--safe-account-connection-and-interception)  |
| **2 — Reliable delivery batches**                | Controlled live batch groundwork exists; full phase not started | Production windows/calendar, general frozen batches, Check Now, automatic synchronization/reconciliation and batch notification. [Phase 2](docs/email-client-product-implementation-spec.md#phase-2--reliable-delivery-batches)      |
| **3 — Deterministic routing and learning**       | Not started                                                     | Built-in routing, user rules, corrections/Undo, bypass and conversation aggregation. [Phase 3](docs/email-client-product-implementation-spec.md#phase-3--deterministic-routing-and-learning)                                         |
| **4 — Reading and triage Room**                  | Not started; metadata preview only                              | Doorstep/Caught Up, safe Letter rendering, attachments, Pile, Desk/horizons, Drawer/Keep. [Phase 4](docs/email-client-product-implementation-spec.md#phase-4--reading-and-triage-room)                                               |
| **5 — Compose, reply and open loops**            | Not started                                                     | Draft recovery, replies, safe sending, post-send disposition, Waiting reactivation and external-send reconciliation. [Phase 5](docs/email-client-product-implementation-spec.md#phase-5--compose-reply-and-open-loops)               |
| **6 — Usability, security and operations**       | Not started as a full phase                                     | Keyboard/accessibility, visual consistency, security review, failure injection, settings and supportability. [Phase 6](docs/email-client-product-implementation-spec.md#phase-6--usability-security-and-operational-hardening)       |
| **7 — Two-week dogfood and product decision**    | Not started                                                     | Baseline, controlled activation, daily use and evaluation. Commercialization is a later decision, not an approved launch. [Phase 7](docs/email-client-product-implementation-spec.md#phase-7--two-week-dogfood-and-product-decision) |

## How we maintain this tracker

1. Continue autonomously through feasible work; commit verified slices and push
   regularly. Pause only for genuinely required owner answers/actions. Do not
   treat routine next steps as awaiting approval.
2. Read this tracker at the start of a work session and check it against the
   current code and evidence.
3. When a slice begins, name it under Current position; distinguish approved
   work from proposals. Do not mark something blocked merely because it has not
   started.
4. At completion, update status, verification results, evidence links, remaining
   limitations and the next recommended action. Mark user-reported observations
   separately from independently verified results.
5. End the user-facing completion message with one concrete next action and any
   decision the owner needs to make. Group human setup into manageable batches.
6. Use the mockups and `design` skill for UI work. Verify current compatible
   versions from official sources whenever adding or upgrading dependencies.
7. Keep sensitive account information, messages, credentials and tokens out of
   this tracker. Do not use a percentage complete: implementation and real-world
   proof have different requirements.

## Recent completions

| Date       | Result                                                                                           | Reference                                                                                                                                          |
| ---------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-05 | Interrupted three-message hold survived restart and recovered without duplicate writes | [Evidence](docs/evidence/phase-0/2026-09-05-live-hold-recovery.md); all three restored unread to Inbox at repeat revision three |
| 2026-09-05 | New arrival stayed outside interrupted batch; recovery left its labels unchanged | [Evidence](docs/evidence/phase-0/2026-09-05-live-arrival-recovery.md); one remaining write, originals and newcomer unread in Inbox |
| 2026-09-05 | Safe disconnect restored all three held messages before revocation; reconnect passed             | [Evidence](docs/evidence/phase-0/2026-09-05-held-batch-disconnect.md); guarded repeat deployed, 138 backend / 23 browser tests                     |
| 2026-09-05 | Interrupted revocation recovered after restart; cleanup and reconnect passed                     | [Evidence](docs/evidence/phase-0/2026-09-05-live-revoke-recovery.md); zero refresh/Gmail requests on retry                                         |
| 2026-09-05 | Live three-message release crash recovered across restart with no duplicate writes               | [Evidence](docs/evidence/phase-0/2026-09-05-live-batch-recovery.md); all three returned to Inbox unread                                            |
| 2026-09-05 | Fixed three-message Gmail batch deployed; per-message recovery and safe disconnect tested        | [Evidence](docs/evidence/phase-0/2026-09-05-controlled-batch.md); 136 backend / 23 browser tests; subsequent live proof in the newer entries above |
| 2026-09-05 | Live hold/release request crashes recovered after web restart with zero duplicate writes         | [Evidence](docs/evidence/phase-0/2026-09-05-live-crash-recovery.md); 14 focused tests                                                              |
| 2026-09-05 | Daily encrypted VM backups enabled; actual archive restored independently                        | [Evidence](docs/evidence/phase-0/2026-09-05-vm-backups.md); four runner tests, 129 backend tests                                                   |
| 2026-09-05 | Direct Gmail app-outage recovery and independent local restore passed for one fixture            | [Evidence](docs/evidence/phase-0/2026-09-05-independent-recovery.md); full operational gates remain open                                           |
| 2026-09-05 | Controlled safe disconnect from held passed live; repeat action deployed                         | 129 backend / 18 browser tests; [evidence](docs/evidence/phase-0/2026-09-05-held-disconnect.md)                                                    |
| 2026-09-04 | Durable scheduling, provider/notification fault tests, encrypted restore and read-only inventory | 98 backend / seven browser tests; current build and restore rehearsal pass                                                                         |
| 2026-09-04 | Recovery fence, finite batch review and DST occurrence resolution                                | 78 backend tests; local evidence above                                                                                                             |
| 2026-09-04 | Synthetic journal and executable work-item contract                                              | 62 backend tests; release-journal and workflow evidence above                                                                                      |
| 2026-09-04 | Written contract, Render release/restore guard and recovery preparation                          | `e897234`, `36df39b`; 52 backend tests, local release smoke, Blueprint schema validation                                                           |
| 2026-09-04 | Desk-inspired preview styling and visual checks                                                  | Design evidence; 47 backend and seven browser tests                                                                                                |
| 2026-09-04 | Read-only five-message preview                                                                   | `0618405`, listing evidence                                                                                                                        |
| 2026-09-04 | Real refresh after simulated local expiry                                                        | `c79bc69`, connection evidence                                                                                                                     |
| 2026-09-04 | Restricted encrypted Google connection                                                           | `75be2ad`, connection evidence                                                                                                                     |
| 2026-09-04 | Foundation, synthetic snapshot/Oban proof and architecture                                       | Foundation evidence and ADR-0001                                                                                                                   |
