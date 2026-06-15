#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

export MIX_ENV="${MIX_ENV:-prod}"

run_mix() {
  if command -v mix >/dev/null 2>&1; then
    mix "$@"
  elif command -v mise >/dev/null 2>&1; then
    mise exec erlang@26.2.5 elixir@1.16.3-otp-26 -- mix "$@"
  elif [ -x "$HOME/.local/bin/mise" ]; then
    "$HOME/.local/bin/mise" exec erlang@26.2.5 elixir@1.16.3-otp-26 -- mix "$@"
  else
    echo "Error: mix command not found. Install Elixir or mise before building." >&2
    exit 1
  fi
}

echo "Building minesweeper_backend with MIX_ENV=$MIX_ENV"

run_mix local.hex --force
run_mix local.rebar --force
run_mix deps.get --only "$MIX_ENV"
run_mix deps.compile
run_mix compile
run_mix release --overwrite

echo "Build complete: _build/$MIX_ENV/rel/minesweeper_backend"
