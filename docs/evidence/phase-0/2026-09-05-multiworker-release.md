# Separate-process live release contention

Date: 2026-09-05. Revision: `6679507`, existing exe.dev VM. Status: Pass for two
independent release executors contending over the same frozen three-message batch.

After the filter experiment was disabled, all three original controlled batch
members were verified released and unread. The existing revision-guarded repeat
operation re-held only those saved IDs, advancing repeat revision three to four.
It made three bounded writes and verified all three held, with zero pending/errors.
The one-shot filter record was not reset or reactivated.

Two separate OS processes, each with its own BEAM runtime, application supervision
tree and database pool, then executed Batch.run release against the same saved
batch. They used the existing web container's runtime configuration with HTTP
serving disabled in their own processes; neither was an RPC process inside the
already-running web BEAM. Their distinct recorded OS PIDs were 1457 and 1456.

The first executor paused in its first provider GET while holding the database
operation lock. A filesystem barrier required the second executor to attempt
release during that pause. The second received operation_in_progress before any
provider reads or writes, recorded that result, and waited. The first then
released all three saved messages using exactly three writes, one per ID. After
completion, the second retried in its own still-running process: successful
released state, **zero writes**.

Each executor's provider adapter allowed only GET of the three saved IDs and
exact hold/release label projections for those IDs. Requests to other messages,
filters, hosts or operations were refused. Final metadata/label comparison matched
the pre-hold snapshot for every member, including UNREAD and INBOX. Membership was
unchanged; the batch is released at revision four, three released, zero held,
zero pending/errors.

Private starting metadata/results were copied to the owner Mac. Temporary scripts,
barrier files and snapshots were removed from the VM/container. Their BEAM
processes exited. The ordinary web/worker stayed available, and the final
operational check-only probe returned healthy. No new mail was sent.

This proves separate-process database serialization, one coherent live release
and a write-free losing-worker retry for existing fixed membership. It does not
wire Gmail into scheduled Oban delivery or pass scheduled-versus-Check-Now,
panic/disconnect races, continuous synchronization, history recovery or broader
arrival semantics. Earlier crash and newcomer-exclusion evidence remains separate.
