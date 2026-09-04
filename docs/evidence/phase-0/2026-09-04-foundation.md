# Phase 0 foundation evidence — 2026-09-04

Status: Local foundation verified; Phase 0 exit gate remains open.

Environment: local macOS, dedicated PostgreSQL cluster on loopback port 55432, separate development/test databases, versions in [dependency baseline](../../dependency-versions.md). Synthetic identifiers only. No Google account, Render environment, external monitoring, or backup provider was used.

## Observed results

| Experiment | Result | Evidence / limit |
|---|---|---|
| Phoenix/Inertia/React initial render and client navigation | Pass | Chromium Playwright test loaded the page, followed an Inertia link, used browser Back, and observed no browser errors/warnings |
| Visual and accessibility inspection | Pass for the small shell | Isolated Chrome DevTools context showed the main landmark, ordered headings, readable connection state, and named navigation; desktop screenshot inspected. This is not a full accessibility audit |
| Database readiness | Pass | `/health/ready` returns only `{"status":"ok"}` after a database query |
| Frozen synthetic membership | Pass | IDs are deduplicated/sorted; a second request while pending returns the original snapshot without adding later IDs |
| Atomic snapshot and enqueue | Pass | Outer database rollback removes both the Ash record and Oban job |
| Concurrent snapshot requests | Pass | Six barrier-synchronized tasks held six distinct PostgreSQL backend connections; all returned one snapshot and one persisted job |
| Database invariant enforcement | Pass | Direct SQL attempting to change membership fails with a check violation; direct insertion of a competing pending snapshot fails with a unique violation |
| Duplicate probe job execution | Pass | Repeated verification converges on `verified`; does not represent release of mail |
| Independent worker process | Pass | `APP_ROLE=worker` consumed a job submitted by a separate BEAM process; two synthetic IDs remained unchanged in verified snapshot `4c7fe813-f6e1-429f-b6b9-b12d5d0216f9` |
| Dependency resolution and build | Pass with upstream compiler warnings documented | Exact runtime/package baseline resolves, application compilation passes `--warnings-as-errors`, TypeScript check and esbuild build pass |
| Clean install and security advisory check | Pass | `npm ci` succeeds from lockfile; audit reports zero vulnerabilities after the documented qs patch |
| Production release | Pass locally | `MIX_ENV=prod mix release` builds; release booted on port 4001 with synthetic database settings; page/readiness/JS/CSS returned HTTP 200 |

Final backend suite at this slice: **15 passing tests**. Browser suite: **1 passing test**. Ash migration generation `--check`, formatter check, and git whitespace check pass. These checks verify a limited foundation, not full product correctness.

## Test-driven observations

The initial route tests failed on the missing Phase 0/readiness routes and welcome page; they passed after implementation. Snapshot tests initially failed because the domain did not exist. The direct-SQL immutability test then failed because membership could be changed; it passed after adding the PostgreSQL trigger. Browser inspection caught incorrectly located bundled assets (404), and the corrected build output passed the navigation test.

## What is deliberately not proven

The `PhaseZero.Snapshot` resource is a synthetic persistence experiment, not the production mail/batch schema. `VerifySnapshot` reads and updates that record only. It does not call Gmail, move labels, verify interception, implement recovery, or test ambiguous provider responses. The array of IDs is sufficient for this probe; production release still requires the planned per-message journal.

No claim is made about arrival interception, bypass, notification suppression, history synchronization, OAuth expiry, partial Gmail release, panic/disconnect, independent alert delivery, database restore, or data loss/recovery time. All related exit checkboxes in the [Phase 0 plan](../../phase-0-gmail-reliability-proof.md) remain unchecked.

## Next implementation slice

1. Finish the product transition contract and resolve the plan's open semantic questions.
2. Configure a dedicated Gmail test identity and OAuth client using [test-account setup](../../phase-0-test-account-setup.md).
3. Implement and test the server-side OAuth connection, identity restriction, encrypted token storage, redaction, and disconnected/error states.
4. Deploy the isolated test environment on Render with external operational alerts before enabling test interception.
5. Execute and record the real Gmail and device experiments, then recovery/restore rehearsals.
