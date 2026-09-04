# Deliberate email

A personal Gmail client in Phase 0: prove delivery and recovery before building the full Room. This repository currently has a Phoenix/Ash/PostgreSQL/Oban foundation with a React/TypeScript/Inertia browser shell. No Gmail account is connected and no mail can be intercepted or sent.

## Requirements

Use the exact runtimes in `mise.toml` and PostgreSQL 18.6. See [verified versions](docs/dependency-versions.md) for current release sources and the Inertia compatibility exception. `mix.lock` and `assets/package-lock.json` pin dependencies.

```sh
mise install
mise exec -- mix deps.get
cd assets
mise exec -- npm ci
mise exec -- npm run build
cd ..
```

A local PostgreSQL instance is expected at `127.0.0.1:55432`, with the local-only `postgres` development user. Set `PGHOST`/`PGPORT` to change the address. Development and test use separate databases. Never point these commands at a production database.

On macOS with PostgreSQL 18 installed through Homebrew, initialize a dedicated local cluster once:

```sh
mkdir -p .local
/opt/homebrew/opt/postgresql@18/bin/initdb -D .local/postgres -U postgres --auth-local=trust --auth-host=trust --encoding=UTF8 --locale=C
/opt/homebrew/opt/postgresql@18/bin/pg_ctl -D .local/postgres -l .local/postgres.log -o '-p 55432 -h 127.0.0.1' start
```

This cluster trusts local connections and binds only to loopback. It is for synthetic development data only. `.local/` is ignored by git.

```sh
mise exec -- mix ecto.setup
mise exec -- mix phx.server
```

Open [localhost:4000](http://localhost:4000). During frontend work, run `mise exec -- npm run watch` from `assets/` in another terminal.

## Verification

```sh
mise exec -- mix format --check-formatted
mise exec -- mix compile --warnings-as-errors
mise exec -- mix test
cd assets
mise exec -- npm run typecheck
mise exec -- npm run build
mise exec -- npm audit
mise exec -- npx playwright install chromium
mise exec -- npm test
```

The browser test currently expects the development server at port 4000. Application compilation is warning-free; some upstream packages emit warnings on a fresh Elixir 1.20/OTP 29 dependency compilation. Those are recorded in the version notes rather than hidden.

## Project documents

- [Product specification](docs/email-client-product-implementation-spec.md)
- [Architecture decision](docs/decisions/0001-application-architecture.md)
- [Phase 0 plan and exit gates](docs/phase-0-gmail-reliability-proof.md)

Hosted environments will use Render. Deployment, OAuth, Sentry, Better Stack, R2 backups, and real Gmail/device/recovery experiments are not configured yet. The status page is a read-only development shell, not an authenticated mail client.
