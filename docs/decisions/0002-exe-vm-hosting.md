# ADR-0002: Host Phase 0 on a dedicated exe.dev VM

Date: 2026-09-04. Accepted by the owner through the decision to create a dedicated VM and provide SSH access.

This supersedes ADR-0001's Render-only hosting decision. The application stack and Gmail proof gates are unchanged. The owner prefers to use existing exe.dev capacity rather than pay separately for Render web, worker and database compute.

Use one dedicated VM with Docker Compose: Phoenix web and Oban worker in separate containers using the same release image, plus PostgreSQL 18 on a persistent Docker volume. Separate containers have no per-service hosting fee on this VM and retain independent worker-stop/concurrency experiments. PostgreSQL has no published host port; the application uses a non-superuser database owner. exe.dev supplies the HTTPS proxy, initially restricted to the owner's existing VM access.

We now own operating-system and database updates, capacity monitoring, database backups and restoration. A persistent volume is not an independent backup. R2 encrypted exports and external alerts remain required before personal dogfood; provider disk copies must not be represented as a tested managed PostgreSQL recovery service.

Replace Render-specific hosted checks with equivalent exe.dev checks: Linux release build, migrations, HTTPS, separate worker execution, full VM outage alerts and isolated database restore. The multi-worker race and direct Gmail recovery experiments remain required. Gmail access/interception is not authorized by choosing a host.

Keep `render.yaml` as an unused alternative. Do not create Render resources for this deployment. Follow [exe.dev setup](../exe-phase-0-setup.md); results belong in dated evidence.

Sources: [exe.dev persistent disks](https://exe.dev/docs/serverful), [HTTPS proxy](https://exe.dev/docs/proxy), [Phoenix releases](https://phoenix.hexdocs.pm/releases.html), [PostgreSQL image](https://hub.docker.com/_/postgres).
