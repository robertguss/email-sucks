# Verified dependency baseline

Checked 2026-09-04 against live official release feeds, Hex, and npm, then resolved and compiled locally. Search-index results lagged several registry releases; registry metadata is the source for exact package versions below. This is the starting baseline, not a perpetual claim that these remain latest.

| Component | Selected version | Source / compatibility |
|---|---|---|
| Elixir | 1.20.4 | [Official documentation](https://elixir-lang.org/docs/): supports OTP 27–29 |
| Erlang/OTP | 29.0.6 | [Official latest-release API](https://api.github.com/repos/erlang/otp/releases/latest) |
| Node.js | 26.8.1 | [Official release index](https://nodejs.org/dist/index.json); latest Current, rather than older LTS, per latest-compatible requirement |
| PostgreSQL | 18.6 locally; major 18 on Render | [Official versions feed](https://www.postgresql.org/versions.json); [Render supports major 18](https://render.com/docs/postgresql-creating-connecting). Render manages its patch rollout; verify actual hosted version when provisioning |
| Phoenix / generator | 1.8.13 | [Hex metadata](https://hex.pm/api/packages/phoenix) |
| Ash | 3.32.3 | [Hex metadata](https://hex.pm/api/packages/ash) |
| AshPostgres | 2.13.0 | [Release requirements](https://hex.pm/api/packages/ash_postgres/releases/2.13.0): Ash ~> 3.32 and Ecto ~> 3.13 |
| Ecto / Ecto SQL | 3.14.2 / 3.14.0 | [Ecto](https://hex.pm/api/packages/ecto), [Ecto SQL](https://hex.pm/api/packages/ecto_sql); resolved requirements agree with Ash and Oban |
| Postgrex | 0.22.4 | [Hex metadata](https://hex.pm/api/packages/postgrex) |
| Oban | 2.24.1 | [Release requirements](https://hex.pm/api/packages/oban/releases/2.24.1); [migration version 14](https://hexdocs.pm/oban/Oban.Migration.html) |
| Bandit | 1.12.5 | [Hex metadata](https://hex.pm/api/packages/bandit) |
| Phoenix Inertia adapter | 2.6.2 | [Hex metadata](https://hex.pm/api/packages/inertia); latest stable; 3.0.0-rc5 is a prerelease |
| Inertia React client | 2.3.27 | [npm metadata](https://registry.npmjs.org/@inertiajs/react/2.3.27); latest stable v2 paired with stable Phoenix adapter |
| React / React DOM | 19.2.8 | [React](https://registry.npmjs.org/react/latest), [React DOM](https://registry.npmjs.org/react-dom/latest); supported by the selected Inertia client peer range |
| TypeScript | 7.0.2 | [npm metadata](https://registry.npmjs.org/typescript/latest) |
| esbuild | 0.28.2 | [npm metadata](https://registry.npmjs.org/esbuild/latest); direct build script, no extra Vite integration needed for this slice |
| Playwright | 1.62.1 | [npm metadata](https://registry.npmjs.org/@playwright/test/latest); browser installation supplied Chromium 151.0.7922.34 |

Use lockfiles for the full transitive dependency graph and exact React type-package versions. npm dependencies are exact pins; Mix requirements allow compatible patches and the lockfile fixes the installed release.

## Compatibility exception: Inertia

The latest npm client is 3.7.0, but the Phoenix v3 adapter is still a release candidate. Use the stable v2 adapter/client pair for the initial proof. The [tagged adapter documentation](https://github.com/inertiajs/inertia-phoenix/blob/v2.6.2/README.md) describes the v2 integration. Upgrade both sides together when a stable v3 adapter is available and rerun navigation, forms/CSRF, history, and error-handling tests. Only navigation/history are proven in the current slice.

## Dependency audit and caveats

The initial npm resolution selected vulnerable `qs` 6.15.3. Its parent's `^6.15.0` range accepts the fixed 6.16.0 release. Pin an explicit transitive override to 6.16.0 and retain a clean `npm audit` result. See the [maintainer package](https://registry.npmjs.org/qs/latest) and advisories [GHSA-x5fp-wj9c-mxmx](https://github.com/advisories/GHSA-x5fp-wj9c-mxmx), [GHSA-4mjr-xmp4-gh2g](https://github.com/advisories/GHSA-4mjr-xmp4-gh2g).

The machine's npm minimum-release-age setting initially excluded this fix. Installation used a command-scoped `--min-release-age=0` for the verified release, consistent with the request for current versions; global policy was not changed. esbuild's installation script is explicitly allowed. Node is invoked through `mise exec` so shell PATH does not silently choose the older installed Node 24.

Fresh dependency compilation emits upstream warnings in packages including Ash, Multigraph, Crux, DNSCluster, Inertia, and Yamerl under Elixir 1.20/OTP 29, plus deprecated dependency `xref` configuration. They currently compile successfully. Do not edit vendored dependencies or suppress application warnings to hide these. Re-evaluate if any becomes a runtime failure or blocks a future compiler update.

Sentry, Google OAuth/HTTP libraries, and backup tooling will be verified again when their implementation slice begins. They are architecture selections, not installed integrations in this slice.
