FROM node:26.8.1-bookworm-slim AS assets
WORKDIR /app/assets
COPY assets/package.json assets/package-lock.json ./
RUN npm ci
COPY assets/ ./
RUN npm run typecheck && npm run build

FROM hexpm/elixir:1.20.4-erlang-29.0.6-debian-bookworm-20260824-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends build-essential git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV MIX_ENV=prod
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/
RUN mix deps.get --only prod --check-locked && mix deps.compile
COPY lib/ lib/
COPY priv/ priv/
COPY --from=assets /app/priv/static/assets/ priv/static/assets/
RUN mix compile --warnings-as-errors
COPY config/runtime.exs config/
RUN mix release

FROM debian:bookworm-20260824-slim
RUN apt-get update && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=C.UTF-8 MIX_ENV=prod
WORKDIR /app
COPY --from=builder --chown=nobody:nogroup /app/_build/prod/rel/email_sucks/ ./
USER nobody
CMD ["/app/bin/email_sucks", "start"]
