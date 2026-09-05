# Project progress

Last updated: 2026-09-05

This is the current status and next-action tracker. The [product specification](docs/email-client-product-implementation-spec.md#26-phased-implementation-plan) defines scope and acceptance criteria; the [Phase 0 proof plan](docs/phase-0-gmail-reliability-proof.md) defines the detailed experiments. Evidence documents are dated records, not the current work queue.

## Current position

**Phase 0 is in progress; its exit gate has not passed.** The authenticated app previews five Inbox messages and now implements one controlled message hold/release with durable recovery. Automatic interception, continuous sync and sending remain disabled. Hosted read-only sign-in and preview have live evidence; the new modification flow still requires hosted consent and a live app run.

**Latest implemented slice:** exact fixture matching, message-level label changes, independently committed pending intent, serialized operations, provider read-back and explicit recovery. The UI exposes saved state and last verification time honestly. See the [controlled app experiment](docs/phase-0-controlled-filter-experiment.md). Automated provider simulations include real-commit killed-request recovery; they do not replace live Gmail evidence.

## Next action

Deploy the controlled flow, reconnect through the app for Gmail modification permission, and run the hold/recover/release/verify sequence against the existing disposable fixture. The manual Gmail filter exercise is superseded and must not be repeated. The owner has authorized implementation, verification, pushing to main and deployment to the existing exe.dev VM. Group any human Google instructions into one manageable batch.

The owner waived manual export of disposable test mail. Product-wide recovery requirements remain in force. Native notification proof needs actual owner devices, and full Phase 0 acceptance still needs empirical evidence.

Render provisioning is superseded by the dedicated exe.dev VM. Hosted alert receipt, independent backup scheduling and total-VM-loss recovery still need evidence. Full Room, production mail mutations and personal dogfood remain gated on Phase 0 results.

Autonomous work, verified commits and regular pushes remain authorized. Resume independent work when new information or the live results establish the next supported implementation step; no routine reapproval is needed.

## Completed work and evidence

| Work | Status | Evidence and limits |
|---|---|---|
| Architecture choice | Decided | [ADR-0001](docs/decisions/0001-application-architecture.md): Elixir/Phoenix/Ash, React/Inertia, PostgreSQL/Oban, R2, Sentry and Better Stack; [ADR-0002](docs/decisions/0002-exe-vm-hosting.md) replaces Render with exe.dev. Choosing a service does not mean it is configured. |
| Compatible dependency baseline and local app | Verified locally | [Foundation evidence](docs/evidence/phase-0/2026-09-04-foundation.md), [versions](docs/dependency-versions.md). Local build/release, database readiness, browser navigation. |
| Immutable snapshots and atomic job enqueue | Verified with synthetic data | Foundation evidence: concurrency, rollback, membership invariants, duplicate execution and separate worker. No real Gmail release yet. |
| Restricted Google OAuth and encrypted credentials | Implemented; live sign-in verified | [Connection evidence](docs/evidence/phase-0/2026-09-04-google-connection.md). Tests cover state/nonce/PKCE, signed identity, allowed account, replay and session controls. |
| Gmail profile check | Verified live | Owner completed sign-in; browser and database showed successful verification. |
| Automatic token refresh | Verified live with simulated local expiry | Connection evidence: real Google refresh and profile check, same browser session, valid future expiry, released lease. Natural expiry and provider refresh-token rotation remain unproven. |
| Revocation detection and reconnection | Owner-reported live pass | Owner removed the Google grant, observed the reconnect message, reauthorized, and reported “connection verified.” This did not exercise held-mail recovery. |
| Five-message Inbox metadata preview | Implemented and verified live | [Listing evidence](docs/evidence/phase-0/2026-09-04-read-only-message-list.md). No bodies/attachments, database persistence of email metadata, or Gmail mutations. |
| Desk-inspired preview design | Implemented and visually verified | [Design evidence](docs/evidence/phase-0/2026-09-04-desk-preview-design.md): local Newsreader, responsive whitespace-led layout, light/dark themes, connection disclosure and interaction states. Full Room design implementation remains later work. |
| Written state contract | Complete as documentation | [Contract](docs/phase-0-state-contract.md); runtime and live-provider proof remain separate. |
| Render release and restore startup | Verified locally; not deployed | [Evidence](docs/evidence/phase-0/2026-09-04-render-preparation.md), [setup](docs/render-phase-0-setup.md). Retained as an unused alternative after the exe.dev decision. |
| Recovery card and experiment inventory | Prepared, not rehearsed | [Card](docs/phase-0-offline-recovery-card.md), [scope/fixture inventory](docs/phase-0-experiment-inventory.md). Private account details and device results pending. |
| Per-message release journal | Verified with synthetic outcomes | [Evidence](docs/evidence/phase-0/2026-09-04-release-journal.md); live provider integration remains open. |
| Executable work-item contract | Verified locally | [Evidence](docs/evidence/phase-0/2026-09-04-workflow-contract.md); calendar dates, Waiting visibility and confirmed-send guards. Not a persisted workflow engine. |
| Account recovery fence | Verified with synthetic accounts | [Evidence](docs/evidence/phase-0/2026-09-04-recovery-fence.md); database serialization and in-flight accounting, not actual mailbox restoration. |
| Finite batch review | Verified with synthetic outcomes | [Evidence](docs/evidence/phase-0/2026-09-04-batch-review.md); separate per-batch review and pending-delivery status, no UI integration. |
| Local occurrence resolution | Verified with IANA data | [Evidence](docs/evidence/phase-0/2026-09-04-delivery-occurrences.md); DST gaps/overlaps, stable identity and explicit date exceptions. Durable scheduler remains unimplemented. |
| Durable scheduling probe | Verified locally | [Evidence](docs/evidence/phase-0/2026-09-04-durable-scheduling.md); saved occurrences, coalescing, revision edits, manual receipts and account serialization. No timer/Gmail integration. |
| Encrypted local backup and restore | Verified on disposable databases | [Evidence](docs/evidence/phase-0/2026-09-04-local-backup-restore.md); actual pg_dump/age/pg_restore, corruption/key checks, inert restored jobs. No R2/Render proof. |
| Read-only identity/filter inventory | Implemented and tested with fixtures | [Evidence](docs/evidence/phase-0/2026-09-04-read-only-inventory.md); authenticated internal API, no new scopes/UI or live inventory proof. |
| Primary-address ordinary arrival | Owner-reported live baseline | [Evidence](docs/evidence/phase-0/2026-09-04-primary-arrival-baseline.md); synthetic message visible in Inbox through direct Gmail access. Interception and recovery remain untested. |
| Dedicated exe.dev deployment | Verified with synthetic data | [Evidence](docs/evidence/phase-0/2026-09-04-exe-deployment.md): Linux build, migrations, web readiness, separate worker, restart and one-off encrypted restore. Hosted OAuth, R2 scheduling and outage alerts pending. |
| Hosted read-only OAuth configuration | Live sign-in/profile/preview verified | [Evidence](docs/evidence/phase-0/2026-09-04-hosted-oauth-setup.md): separate client/keys, web-only read-only mounts, corrected production compile setting and live inventory (three existing filters). |
| Shared progress tracking | Complete | This document is linked from README and the Phase 0 plan. |

## Phase 0 work remaining

Checked items require their stated evidence; implementation alone does not pass a proof gate.

- [x] **0.1 — Written state and workflow contract:** [transition table and decisions](docs/phase-0-state-contract.md), with illegal states, calendar semantics and acceptance examples. Runtime implementation and provider experiments are separate gates; the static app page is not the full contract.
- [ ] **Test environment:** [exe.dev setup](docs/exe-phase-0-setup.md) passed initial synthetic hosted checks; owner browser access is screenshot-confirmed; hosted sign-in/profile/preview and read-only inventory passed. Still document test identities, controlled fixtures, existing Gmail filters, devices and notification settings. Complete hosted checks on the isolated exe.dev environment before test interception.
- [ ] **Provider error classification:** distinguish a disabled Gmail API from missing OAuth permission; the hosted setup exposed an incorrect blanket HTTP 403 mapping.
- [ ] **Authorization lifecycle:** [method/scope inventory](docs/phase-0-experiment-inventory.md) prepared; settle the dogfood authorization strategy; distinguish natural token expiry, revocation and refresh-token rotation. Inventory additional scopes before any mutation work.
- [ ] **0.2 — Interception matrix:** prove primary address, aliases, forwarding, Bcc, lists, existing threads, unusual mail and filter conflicts; document unsupported cases.
- [ ] **0.3 — Notification/badge matrix:** observe held arrival, bypass and release on actual devices; choose and prove the app alert behavior.
- [ ] **Real finite release:** implement per-message progress and prove fixed membership through retries, partial success, lost responses, worker crashes and concurrent arrivals. The [synthetic journal](docs/evidence/phase-0/2026-09-04-release-journal.md) now covers claims, partial outcomes and stale workers; synthetic account recovery races now pass; live Gmail effects and provider recovery races remain unproven.
- [ ] **0.4 — Panic and direct Gmail recovery:** [offline recovery card](docs/phase-0-offline-recovery-card.md) prepared but not filled/rehearsed; disable interception before restoring held mail, and rehearse with the app unavailable.
- [ ] **Safe disconnect:** restore and verify held mail before revocation, including interrupted recovery. Current app sign-out only ends the browser session.
- [ ] **Independent monitoring:** configure Sentry and Better Stack with redaction; test meaningful failed-work and missed-heartbeat alerts, including total VM outage.
- [ ] **Backups and restore:** configure independent encrypted PostgreSQL exports and R2 copies; restore both into isolated environments with Gmail writes/jobs disabled and verify reconciliation and measured losses/recovery time.
- [ ] **Exit review:** review the recorded evidence and explicitly accept provider/device limitations and state semantics. Only then move to full product implementation.

### Remaining external decisions and proof

| Decision | Needed before |
|---|---|
| Arrival-time bypass support, including conversation rules | Live interception experiment; no unsupported promise may be activated |
| Native read/unread and device notifications | Actual device matrix before policy changes |
| Independent alert destination and off-VM backup retention/key custody | Operational proof before dogfood |
| Retention, recovery-key custody and acceptable measured recovery loss/time | Backup/restore acceptance and dogfood |

The state contract resolves implementation semantics under the autonomous-work instruction. Live-provider limitations and operational acceptance still require evidence; older recommendations in the proof plan are superseded only by the explicitly recorded contract defaults.

## Full product roadmap

| Phase | Status | What remains / completion reference |
|---|---|---|
| **0 — Product contract and Gmail feasibility** | In progress | Checklist above; all exit gates remain open. |
| **1 — Safe account connection and interception** | Not complete; connection groundwork exists | Production-ready identity/onboarding, app-owned Gmail resources, safety rehearsal, health, panic and safe disconnect. [Phase 1](docs/email-client-product-implementation-spec.md#phase-1--safe-account-connection-and-interception) |
| **2 — Reliable delivery batches** | Not started beyond synthetic probe | Windows/calendar, real frozen batches, Check Now, synchronization/reconciliation and batch notification. [Phase 2](docs/email-client-product-implementation-spec.md#phase-2--reliable-delivery-batches) |
| **3 — Deterministic routing and learning** | Not started | Built-in routing, user rules, corrections/Undo, bypass and conversation aggregation. [Phase 3](docs/email-client-product-implementation-spec.md#phase-3--deterministic-routing-and-learning) |
| **4 — Reading and triage Room** | Not started; metadata preview only | Doorstep/Caught Up, safe Letter rendering, attachments, Pile, Desk/horizons, Drawer/Keep. [Phase 4](docs/email-client-product-implementation-spec.md#phase-4--reading-and-triage-room) |
| **5 — Compose, reply and open loops** | Not started | Draft recovery, replies, safe sending, post-send disposition, Waiting reactivation and external-send reconciliation. [Phase 5](docs/email-client-product-implementation-spec.md#phase-5--compose-reply-and-open-loops) |
| **6 — Usability, security and operations** | Not started as a full phase | Keyboard/accessibility, visual consistency, security review, failure injection, settings and supportability. [Phase 6](docs/email-client-product-implementation-spec.md#phase-6--usability-security-and-operational-hardening) |
| **7 — Two-week dogfood and product decision** | Not started | Baseline, controlled activation, daily use and evaluation. Commercialization is a later decision, not an approved launch. [Phase 7](docs/email-client-product-implementation-spec.md#phase-7--two-week-dogfood-and-product-decision) |

## How we maintain this tracker

1. Continue autonomously through feasible work; commit verified slices and push regularly. Pause only for genuinely required owner answers/actions. Do not treat routine next steps as awaiting approval.
2. Read this tracker at the start of a work session and check it against the current code and evidence.
3. When a slice begins, name it under Current position; distinguish approved work from proposals. Do not mark something blocked merely because it has not started.
4. At completion, update status, verification results, evidence links, remaining limitations and the next recommended action. Mark user-reported observations separately from independently verified results.
5. End the user-facing completion message with one concrete next action and any decision the owner needs to make. Walk human setup steps one at a time.
6. Use the mockups and `design` skill for UI work. Verify current compatible versions from official sources whenever adding or upgrading dependencies.
7. Keep sensitive account information, messages, credentials and tokens out of this tracker. Do not use a percentage complete: implementation and real-world proof have different requirements.

## Recent completions

| Date | Result | Reference |
|---|---|---|
| 2026-09-04 | Durable scheduling, provider/notification fault tests, encrypted restore and read-only inventory | 98 backend / seven browser tests; current build and restore rehearsal pass |
| 2026-09-04 | Recovery fence, finite batch review and DST occurrence resolution | 78 backend tests; local evidence above |
| 2026-09-04 | Synthetic journal and executable work-item contract | 62 backend tests; release-journal and workflow evidence above |
| 2026-09-04 | Written contract, Render release/restore guard and recovery preparation | `e897234`, `36df39b`; 52 backend tests, local release smoke, Blueprint schema validation |
| 2026-09-04 | Desk-inspired preview styling and visual checks | Design evidence; 47 backend and seven browser tests |
| 2026-09-04 | Read-only five-message preview | `0618405`, listing evidence |
| 2026-09-04 | Real refresh after simulated local expiry | `c79bc69`, connection evidence |
| 2026-09-04 | Restricted encrypted Google connection | `75be2ad`, connection evidence |
| 2026-09-04 | Foundation, synthetic snapshot/Oban proof and architecture | Foundation evidence and ADR-0001 |
