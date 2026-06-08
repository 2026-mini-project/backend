-- =====================================================================
-- sql/001_init.sql
--
-- Bootstraps the minesweeper database with everything the Elixir
-- backend needs. Safe to re-run (uses IF NOT EXISTS everywhere) and
-- mirrors the schema produced by the Ecto migration in
-- priv/repo/migrations/.
--
-- Usage:
--   createdb minesweeper
--   psql "$DATABASE_URL" -f sql/001_init.sql
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------
-- users
--
-- `id` is also the SessionId surfaced to clients via the API.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(32) NOT NULL,
    inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- rooms
--
-- Owner is the user that created the room. Room membership and the
-- `full` boolean are computed at request time from Redis (see
-- MinesweeperBackend.Rooms) so we don't store that here.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rooms (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(64) NOT NULL,
    owner_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    max_players INT         NOT NULL DEFAULT 2,
    inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT  rooms_max_players_positive CHECK (max_players > 0)
);

CREATE INDEX IF NOT EXISTS rooms_owner_id_index ON rooms (owner_id);

-- ---------------------------------------------------------------------
-- schema_migrations
--
-- Pre-populated so a clean `psql -f` run plays nicely with Ecto:
-- `mix ecto.migrate` will treat the bootstrap migration as already
-- applied instead of trying to re-create the tables.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schema_migrations (
    version BIGINT       PRIMARY KEY,
    inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO schema_migrations (version)
VALUES (20260608000001)
ON CONFLICT (version) DO NOTHING;
