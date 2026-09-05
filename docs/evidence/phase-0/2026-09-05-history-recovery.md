# Bounded history recovery — implementation and proof

## Reviewed implementation

The probe freezes the four existing controlled message IDs in its own durable
journal. It captures a profile cursor before metadata reads, catches up through
bounded history pages and atomically checkpoints observations. Unknown IDs never
expand membership. It uses only GET requests and preserves source journals.
Authenticated controls support incremental checks and full rescans; expired
history receives one bounded rescan. No worker receives Gmail credentials.

All 218 backend and 44 browser tests pass, with formatting, compilation with
warnings as errors, TypeScript and diff checks. Tests cover GET-only transport,
known changes, unknown IDs, pagination, expiry, crash durability, lock contention,
checkpoint retention, CSRF/access guards and public summary redaction. Responsive
browser views were inspected at 390 and 1440 pixels.

Simplification and independent review completed. Review run
`20260905-131349-e6bbf5bc` used seven local lenses and Claude Opus 5; two validated
findings were fixed with red/green regressions. Missing scope now records reconnect
required. Completed disconnect retires an old probe error from active health while
preserving its checkpoint; pending disconnect and reconnect failures stay visible.

## Deployment and live proof

Reviewed image `9ef7fe7` deployed at 17:32 UTC. The additive history table migrated
successfully; web and worker run the same image and readiness passed. The
pre-migration archive was copied off the VM, checksum matched and fully
authenticated before migration.

A temporary transport guard allowed only profile, history and exact metadata GETs
for the four saved IDs. Its self-test rejected a write locally. Initial scan
committed revision one; incremental scan committed revision two. Replacing only
one outbound start cursor with `1` produced a real Google HTTP404. The automatic
full rescan succeeded at revision three, with all four messages available. This
was forced old-cursor rejection, not natural expiry of the saved checkpoint.

The proof made 22 reads and zero Gmail writes. Before/after metadata and fixed
membership matched exactly; the entire single, batch and two filter journals were
unchanged. Both filter experiments remain disabled, and the batch remains released
at revision four. Private snapshots remain on the owner Mac.

An injected read-only HTTP503 then retained the successful cursor, observations,
membership, revision, mode and timestamp. The live UI showed the failed check
alongside last-successful counts. Operational health reported
`gmail_operation_failed`; the host monitor correctly failed its check-only run
with `worker_unhealthy`. An authenticated **Rescan saved messages** action recovered
all four members at revision four, cleared the error and restored healthy monitor
checks. External notification delivery was not tested or enabled.

## Fresh restore proof

The 17:34 UTC encrypted backup was copied to the owner Mac and its SHA-256 matched
`fafed52925a560cb94aba5df017dcfdf69fd1413fbf24e7d4ce0a339c9f6f22e`.
`bin/backup-restore` authenticated the entire archive before restoring into a new
isolated local database. Full-row hashes for all four journal tables matched the
live database. The restored application read the successful history checkpoint
with restore mode enabled, no Oban process and no Gmail configuration.

The first local application check used the development database because that
configuration does not consume DATABASE_URL; it read not_started and failed its
assertion without provider calls. The corrected check explicitly selected the
isolated restored database before application startup and passed.

This is a fixed-fixture diagnostic, not full-mailbox discovery or continuous sync.
