# Project progress

Last updated: 2026-09-04

This is the current status and next-action tracker. The [product specification](docs/email-client-product-implementation-spec.md#26-phased-implementation-plan) defines scope and acceptance criteria; the [Phase 0 proof plan](docs/phase-0-gmail-reliability-proof.md) defines the detailed experiments. Evidence documents are dated records, not the current work queue.

## Current position

**Phase 0 is in progress; its exit gate has not passed.** A local, authenticated, read-only Gmail prototype works. It can connect the approved account, refresh access, detect revoked access, reconnect, and display metadata for five Inbox messages. It cannot intercept, release, synchronize continuously, or send mail. Nothing is deployed to Render yet.

**Active implementation:** none. The approved Desk-inspired preview slice is complete and ready for owner review.

**Latest completed slice:** Desk-inspired styling for the read-only preview, using the design skill. Recorded checks: 47 backend tests, seven Chromium tests, TypeScript checking, formatting, and desktop/mobile light/dark visual review. See [design evidence](docs/evidence/phase-0/2026-09-04-desk-preview-design.md). These are results from that slice, not a continuously running health guarantee.

## Recommended next action

**Review the updated preview, then settle the Phase 0 state/transition contract.**

Status: **Proposed — awaiting the owner's review and discussion.**

First decision: how to handle mail already in the Inbox at onboarding. Recommended starting policy: leave existing Inbox messages untouched and apply future delivery controls only to new arrivals after explicit activation. An optional historical import would be a separate decision, not an implied permission to move existing mail.

Scope: work through the open semantic questions one at a time, then write the transition table and illegal-state rules. Do not enable interception or build the full Room as part of this discussion.

Done when: every primary action has a before-state, guard, after-state and Gmail effect; the owner has approved the remaining state semantics; contract tests and the tracker reflect those decisions.

**After that:** prepare the isolated hosted test environment and the interception/recovery experiment plan, with an offline recovery card before any activation.

## Completed work and evidence

| Work | Status | Evidence and limits |
|---|---|---|
| Architecture choice | Decided | [ADR-0001](docs/decisions/0001-application-architecture.md): Elixir/Phoenix/Ash, React/Inertia, PostgreSQL/Oban, Render, R2, Sentry and Better Stack. Choosing a service does not mean it is configured. |
| Compatible dependency baseline and local app | Verified locally | [Foundation evidence](docs/evidence/phase-0/2026-09-04-foundation.md), [versions](docs/dependency-versions.md). Local build/release, database readiness, browser navigation. |
| Immutable snapshots and atomic job enqueue | Verified with synthetic data | Foundation evidence: concurrency, rollback, membership invariants, duplicate execution and separate worker. No real Gmail release yet. |
| Restricted Google OAuth and encrypted credentials | Implemented; live sign-in verified | [Connection evidence](docs/evidence/phase-0/2026-09-04-google-connection.md). Tests cover state/nonce/PKCE, signed identity, allowed account, replay and session controls. |
| Gmail profile check | Verified live | Owner completed sign-in; browser and database showed successful verification. |
| Automatic token refresh | Verified live with simulated local expiry | Connection evidence: real Google refresh and profile check, same browser session, valid future expiry, released lease. Natural expiry and provider refresh-token rotation remain unproven. |
| Revocation detection and reconnection | Owner-reported live pass | Owner removed the Google grant, observed the reconnect message, reauthorized, and reported “connection verified.” This did not exercise held-mail recovery. |
| Five-message Inbox metadata preview | Implemented and verified live | [Listing evidence](docs/evidence/phase-0/2026-09-04-read-only-message-list.md). No bodies/attachments, database persistence of email metadata, or Gmail mutations. |
| Desk-inspired preview design | Implemented and visually verified | [Design evidence](docs/evidence/phase-0/2026-09-04-desk-preview-design.md): local Newsreader, responsive whitespace-led layout, light/dark themes, connection disclosure and interaction states. Full Room design implementation remains later work. |
| Shared progress tracking | Complete | This document is linked from README and the Phase 0 plan. |

## Phase 0 work remaining

Checked items require their stated evidence; implementation alone does not pass a proof gate.

- [ ] **0.1 — State and workflow contract:** finish the transition table, illegal states, and remaining decisions below. The static contract page is only a starting point.
- [ ] **Test environment:** document test identities, controlled fixtures, existing Gmail filters, devices and notification settings. Select and provision the isolated Render environment before test interception.
- [ ] **Authorization lifecycle:** settle the dogfood authorization strategy; distinguish natural token expiry, revocation and refresh-token rotation. Inventory additional scopes before any mutation work.
- [ ] **0.2 — Interception matrix:** prove primary address, aliases, forwarding, Bcc, lists, existing threads, unusual mail and filter conflicts; document unsupported cases.
- [ ] **0.3 — Notification/badge matrix:** observe held arrival, bypass and release on actual devices; choose and prove the app alert behavior.
- [ ] **Real finite release:** implement per-message progress and prove fixed membership through retries, partial success, lost responses, worker crashes and concurrent arrivals. The synthetic snapshot probe is not sufficient.
- [ ] **0.4 — Panic and direct Gmail recovery:** prepare the offline recovery card, disable interception before restoring held mail, and rehearse with the app unavailable.
- [ ] **Safe disconnect:** restore and verify held mail before revocation, including interrupted recovery. Current app sign-out only ends the browser session.
- [ ] **Independent monitoring:** configure Sentry and Better Stack with redaction; test meaningful failed-work and missed-heartbeat alerts, including total Render outage.
- [ ] **Backups and restore:** configure managed Render recovery and encrypted R2 exports; restore both into isolated environments with Gmail writes/jobs disabled and verify reconciliation and measured losses/recovery time.
- [ ] **Exit review:** review the recorded evidence and explicitly accept provider/device limitations and state semantics. Only then move to full product implementation.

### Decisions still needed

| Decision | Needed before |
|---|---|
| Waiting reply visibility and bypass/emergency-peek behavior | State contract and reactivation implementation |
| Existing Inbox onboarding/import policy | Onboarding and initial synchronization |
| Historical sent-address coverage and alias/self exclusions | Routing heuristics |
| Conversation bypass feasibility and supported promises | Bypass implementation |
| External Gmail edits, deletions and manual moves | Synchronization/reconciliation |
| DST, timezone changes, overdue windows and schedule edits | Delivery scheduling |
| Partial-batch notification and recovery status presentation | Release and alert implementation |
| Render region, service/database plans, budget and independent alert destination | Hosted provisioning |
| Retention, recovery-key custody and acceptable measured recovery loss/time | Backup/restore acceptance and dogfood |

The detailed options live in the Phase 0 plan and ADR; proposals there are not silently treated as approved decisions.

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

1. Read this tracker at the start of a work session and check it against the current code and evidence.
2. When a slice begins, name it under Current position; distinguish approved work from proposals. Do not mark something blocked merely because it has not started.
3. At completion, update status, verification results, evidence links, remaining limitations and the next recommended action. Mark user-reported observations separately from independently verified results.
4. End the user-facing completion message with one concrete next action and any decision the owner needs to make. Walk human setup steps one at a time.
5. Use the mockups and `design` skill for UI work. Verify current compatible versions from official sources whenever adding or upgrading dependencies.
6. Keep sensitive account information, messages, credentials and tokens out of this tracker. Do not use a percentage complete: implementation and real-world proof have different requirements.

## Recent completions

| Date | Result | Reference |
|---|---|---|
| 2026-09-04 | Desk-inspired preview styling and visual checks | Design evidence; 47 backend and seven browser tests |
| 2026-09-04 | Read-only five-message preview | `0618405`, listing evidence |
| 2026-09-04 | Real refresh after simulated local expiry | `c79bc69`, connection evidence |
| 2026-09-04 | Restricted encrypted Google connection | `75be2ad`, connection evidence |
| 2026-09-04 | Foundation, synthetic snapshot/Oban proof and architecture | Foundation evidence and ADR-0001 |
