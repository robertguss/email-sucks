# Deliberate email

**Start here:** [Project progress and next action](PROGRESS.md) — current status, verified results, remaining work, and decisions to discuss. Update it when completing each implementation slice.

A personal Gmail client in Phase 0: prove delivery and recovery before building the full Room. This repository currently has a Phoenix/Ash/PostgreSQL/Oban foundation with a React/TypeScript/Inertia browser shell. It supports a restricted, read-only Google connection, a profile check, and a five-message Inbox preview. No mail can be intercepted or sent.

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

This cluster trusts local connections and binds only to loopback. It is for a trusted, single-user local development machine; it is not a hosted database configuration. OAuth credentials are encrypted before storage. `.local/` is ignored by git.

```sh
mise exec -- mix ecto.setup
mise exec -- mix phx.server
```

Open [localhost:4000](http://localhost:4000). During frontend work, run `mise exec -- npm run watch` from `assets/` in another terminal.

## Read-only Gmail connection

The local callback is `http://localhost:4000/auth/google/callback`. After preparing the private files described in [Google setup](docs/phase-0-test-account-setup.md), run:

```sh
bin/dev-gmail
```

Open [localhost:4000](http://localhost:4000), connect the configured Google account, and then use **Check connection**. The check reads the Gmail account profile; it does not download or modify messages. Use **Load recent messages** for a read-only preview of up to five Inbox messages; only sender, subject, received time and unread status are retrieved. Message bodies are not fetched. Google consent must be completed by the account owner. **Sign out of this app** invalidates the browser session but retains the saved Google grant.

Ordinary `mix phx.server` runs without OAuth unless `GMAIL_OAUTH_FILE` is explicitly set. ExUnit ignores these credential files; browser tests remove the credential-file environment variables from their server process. Keep the private encryption key stable across restarts. See [connection evidence](docs/evidence/phase-0/2026-09-04-google-connection.md) for tests and remaining proof gates.

## Synthetic snapshot probe

The internal `EmailSucks.PhaseZero.freeze/2` function takes an opaque fixture UUID and synthetic message IDs. It atomically persists immutable membership and an Oban verification job. It is not exposed over HTTP and does not call Gmail.

To run the separate development worker:

```sh
APP_ROLE=worker mise exec -- mix run --no-halt
```

The default web role executes no queues. The worker role executes only the synthetic `phase_zero` queue. Real delivery queues do not exist yet. Tests use Oban manual mode. See [local evidence](docs/evidence/phase-0/2026-09-04-foundation.md) and [test-account preparation](docs/phase-0-test-account-setup.md).

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

The browser test builds assets and starts its own Phoenix process at port 4010; leave that port available. Restart your manual development server after changing configuration or dependencies. Application compilation is warning-free; some upstream packages emit warnings on a fresh Elixir 1.20/OTP 29 dependency compilation. Those are recorded in the version notes rather than hidden.

## Project documents

- [Product specification](docs/email-client-product-implementation-spec.md)
- [Architecture decision](docs/decisions/0001-application-architecture.md)
- [Phase 0 plan and exit gates](docs/phase-0-gmail-reliability-proof.md)

A [Render test Blueprint and setup guide](docs/render-phase-0-setup.md) are prepared. `RESTORE_MODE=true` disables Oban startup and Google credential loading for isolated restore checks. Hosted deployment, Sentry, Better Stack, R2 backups, and real Gmail/device/recovery experiments are not completed. The authenticated connection shell is available; the full mail client is not implemented.
