# syntax=docker/dockerfile:1

ARG ELIXIR_IMAGE=elixir:1.16-slim
ARG DEBIAN_VERSION=bookworm-slim

FROM ${ELIXIR_IMAGE} AS build

RUN apt-get update && \
    apt-get install -y build-essential git curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only ${MIX_ENV} && mix deps.compile

COPY lib lib
COPY priv priv
COPY assets assets

RUN mix assets.deploy
RUN mix release

FROM debian:${DEBIAN_VERSION} AS app

RUN apt-get update && \
    apt-get install -y libstdc++6 openssl ncurses-base ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN groupadd --system app && useradd --system --gid app --home /app app
COPY --from=build /app/_build/prod/rel/registratie ./
RUN chown -R app:app /app
USER app

ENV HOME=/app
ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV PORT=8080

EXPOSE 8080
CMD ["/app/bin/registratie", "start"]
