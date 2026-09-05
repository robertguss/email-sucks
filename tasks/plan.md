# Usable controlled delivery experiment

Status: next implementation milestone, selected with the owner on 2026-09-05.
Task checklist: [todo.md](todo.md). Current overall status: [PROGRESS.md](../PROGRESS.md).

## Outcome

Let the owner experience waiting for a delivery, requesting it early with Check Now,
and reviewing a finite batch. Use this same flow to prove the relevant Phase 0
behavior. Phase 0 remains open; this changes implementation order, not acceptance.

The first visible increment is a real batch view backed by the existing saved test
messages. Follow it with repeatable controlled intake and durable timed delivery.
Do not build another diagnostic panel as the primary experience.

## Boundary and reuse

- One connected test account; only explicitly identified test mail in the trial.
  Retain the existing fixture journals as evidence; do not reset them for the new flow.
- Reuse verified Gmail connection, exact-message operations, account serialization,
  frozen membership and recovery behavior where their contracts fit.
- The existing scheduler and release runner are synthetic. Their tests do not prove
  Gmail scheduling. Resolve and test the scheduled-execution boundary before live
  timed intake: workers currently have no Gmail credentials. Do not silently copy
  web secrets into workers or equate a browser countdown with a durable scheduler.
- Review status belongs to the app; preserve Gmail unread state. Start with sender,
  subject and safe preview text. Full HTML reading, compose/reply, automatic routing
  and broad mailbox interception are outside this first experiment.
- Batch notifications stay off. No agent-sent email is authorized. Existing user
  filters remain intact; no general mailbox activation is implied by this milestone.
- Live interception needs exact scope, working stop/restore and an offline recovery
  path. Start with attended test sessions; unattended everyday-mailbox use retains
  the outstanding operational and device gates.

## Pass/fail criteria

Technical pass requires the same bounded stream to arrive held, appear in one
frozen batch at its saved due time or through Check Now, and finish with truthful
per-message outcomes. An arrival during release stays outside that batch. Competing
scheduled/manual work and recovery cannot duplicate or lose membership. Restart
retains due work; failure remains visible; stop prevents further interception and
restores eligible held fixtures without changing unread state or unrelated mail.

Product evaluation requires the owner to use the flow and report whether the next
delivery is understandable, Check Now behaves as expected, the batch feels finite,
and the experience reduces the impulse to monitor email. Automated tests cannot
mark these observations passed. Record confusion and whether the owner wants to
repeat the experiment; do not infer usefulness from successful delivery alone.

If a provider limitation prevents the technical contract, document it and revise
or stop that mechanism. If the flow works but is unhelpful, revise the experience
before broadening the mailbox scope or adding more operational infrastructure.

## Sequence

1. Show and review an existing real test batch.
2. Resolve and verify the durable scheduled Gmail execution boundary.
3. Add isolated repeatable test intake with working stop/restore.
4. Connect due delivery and Check Now to the same frozen batch, with next-delivery UI.
5. Run the attended experiment and record technical evidence plus owner feedback.

Existing state/workflow semantics remain authoritative. Broader identity/Bcc/list/
thread/bypass coverage, native device behavior, full-mailbox recovery/sync and
independent monitoring remain tracked Phase 0 gates, not claims of this experiment.
