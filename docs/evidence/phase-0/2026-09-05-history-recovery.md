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

Pending deployment. Pre-migration backup from 17:09 UTC was copied to the owner Mac,
SHA-256 matched, the complete archive authenticated and PostgreSQL's archive
catalog read successfully. The next proof will use only saved message IDs and
force an old outbound cursor; it does not claim natural checkpoint expiry.

This is a fixed-fixture diagnostic, not full-mailbox discovery or continuous sync.
