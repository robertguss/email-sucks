# Local delivery occurrence resolution evidence

Date: 2026-09-04. Local synthetic scheduling inputs. No scheduler, Gmail operation or hosted deployment activated.

## Dependency verification

The live Hex package registry reported `tz` 0.28.2 as latest stable, with Elixir requirement `~> 1.9`, compatible with the project's Elixir 1.20.4. Official documentation identifies its bundled IANA data as 2026b. The lockfile change adds only `tz`; existing dependencies were retained. No automatic updater or network watcher was added. [Hex package](https://hex.pm/api/packages/tz), [release requirements](https://hex.pm/api/packages/tz/releases/0.28.2), [official documentation](https://tz.hexdocs.pm/readme.html)

## Behavior and verification

`PhaseZero.Occurrence.resolve/5` produces a stable identity scoped to fixture account, schedule revision, local date, minute window and timezone. It returns the requested local time, resolved local time, UTC instant, adjustment and IANA version. Missing local times resolve to the first valid instant on the same date; repeated times select the earlier instant. A wholly skipped date or unknown timezone is an explicit error. Zero fractional precision is normalized; sub-minute windows are rejected.

All 78 backend tests pass. New tests cover New York's spring gap/fall overlap, normal clock preservation across DST dates, Lord Howe's half-hour gap, Samoa's skipped date, unknown zones, identity replay/revision changes and window precision. Production release build and TypeScript check pass. The packaged release independently resolved the New York gap correctly and reported IANA 2026b without starting the application or connecting to a database.

Application compilation and formatting pass. The new dependency emits three upstream unused-require warnings during fresh compilation on Elixir 1.20; those are not application warnings and were not hidden.

## Limits and next action

Occurrence resolution is not a durable scheduler. Persist the selected UTC instant and identity before execution; retries must reuse them even after timezone-data upgrades. Durable occurrence claiming, schedule revision edits, missed-window coalescing, manual/scheduled release races and notifications remain next local work. The WorkItem model still expects already-local dates from its caller. No live provider/device proof gate was passed by these tests.
