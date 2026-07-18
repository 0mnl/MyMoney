-- MyMoney initial schema (v1)
-- Source of truth: docs/MyMoney_Project_Bible.md § 25.4
-- Money: BIGINT in kopecks (see ADR-0002)
-- Sync: last-write-wins by updated_at (see ADR-0004); soft delete via is_deleted
-- All entities are scoped by family_id (family = base data container, see § 10.3)

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users --------------------------------------------------------------

CREATE TABLE app_user (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,               -- argon2id
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Family: base data container, holds all user entities ---------------

CREATE TABLE family (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE family_member (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id  UUID NOT NULL REFERENCES family(id),
    user_id    UUID NOT NULL REFERENCES app_user(id),
    role       TEXT NOT NULL CHECK (role IN ('OWNER', 'MEMBER')),
    joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (family_id, user_id)
);
CREATE INDEX idx_family_member_user ON family_member(user_id) WHERE is_deleted = FALSE;

-- Accounts -----------------------------------------------------------

CREATE TABLE account (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id       UUID NOT NULL REFERENCES family(id),
    name            TEXT NOT NULL,
    type            TEXT NOT NULL,
    currency        TEXT NOT NULL DEFAULT 'RUB',     -- MVP: RUB only
    initial_balance BIGINT NOT NULL DEFAULT 0,       -- kopecks
    is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_account_family ON account(family_id) WHERE is_deleted = FALSE;

-- Categories: two-level hierarchy, system + custom -------------------

CREATE TABLE category (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id          UUID NOT NULL REFERENCES family(id),
    parent_category_id UUID REFERENCES category(id),
    name               TEXT NOT NULL,
    type               TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE')),
    is_mandatory       BOOLEAN NOT NULL DEFAULT FALSE,
    is_system          BOOLEAN NOT NULL DEFAULT FALSE,
    icon               TEXT,
    color              TEXT,
    is_archived        BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_category_family ON category(family_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_category_parent ON category(parent_category_id) WHERE parent_category_id IS NOT NULL;

-- Transactions: income / expense / transfer --------------------------

CREATE TABLE transaction (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id             UUID NOT NULL REFERENCES family(id),
    account_id            UUID NOT NULL REFERENCES account(id),
    category_id           UUID REFERENCES category(id),
    type                  TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE', 'TRANSFER')),
    target_account_id     UUID REFERENCES account(id),
    amount                BIGINT NOT NULL,             -- kopecks
    currency              TEXT NOT NULL DEFAULT 'RUB',
    occurred_at           TIMESTAMPTZ NOT NULL,
    comment               TEXT,
    attachment_photo_path TEXT,
    created_by            UUID NOT NULL REFERENCES app_user(id),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted            BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (
        (type = 'TRANSFER' AND target_account_id IS NOT NULL AND target_account_id <> account_id)
        OR (type <> 'TRANSFER' AND target_account_id IS NULL)
    )
);
CREATE INDEX idx_transaction_family_date ON transaction(family_id, occurred_at DESC) WHERE is_deleted = FALSE;
CREATE INDEX idx_transaction_account ON transaction(account_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_transaction_category ON transaction(category_id) WHERE category_id IS NOT NULL AND is_deleted = FALSE;

-- Transaction history: audit trail (see § 10.4, ADR-0004) ------------

CREATE TABLE transaction_history (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transaction(id),
    snapshot_json  JSONB NOT NULL,
    changed_by     UUID NOT NULL REFERENCES app_user(id),
    changed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_transaction_history_tx ON transaction_history(transaction_id, changed_at DESC);

-- Budget: week / month / year plan per category ----------------------

CREATE TABLE budget (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id      UUID NOT NULL REFERENCES family(id),
    period_type    TEXT NOT NULL CHECK (period_type IN ('WEEK', 'MONTH', 'YEAR')),
    period_start   TIMESTAMPTZ NOT NULL,
    category_id    UUID NOT NULL REFERENCES category(id),
    planned_amount BIGINT NOT NULL,                    -- kopecks
    is_deleted     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_budget_family_period ON budget(family_id, period_type, period_start) WHERE is_deleted = FALSE;

-- Savings goals ------------------------------------------------------

CREATE TABLE goal (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id      UUID NOT NULL REFERENCES family(id),
    name           TEXT NOT NULL,
    target_amount  BIGINT NOT NULL,                    -- kopecks
    current_amount BIGINT NOT NULL DEFAULT 0,
    target_date    TIMESTAMPTZ,
    is_deleted     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_goal_family ON goal(family_id) WHERE is_deleted = FALSE;

-- Debts --------------------------------------------------------------

CREATE TABLE debt (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id         UUID NOT NULL REFERENCES family(id),
    counterparty_name TEXT NOT NULL,
    direction         TEXT NOT NULL CHECK (direction IN ('I_OWE', 'OWED_TO_ME')),
    amount            BIGINT NOT NULL,                 -- kopecks
    due_date          TIMESTAMPTZ,
    status            TEXT NOT NULL CHECK (status IN ('OPEN', 'CLOSED')) DEFAULT 'OPEN',
    is_deleted        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_debt_family ON debt(family_id) WHERE is_deleted = FALSE;

-- Subscriptions ------------------------------------------------------

CREATE TABLE subscription (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id        UUID NOT NULL REFERENCES family(id),
    name             TEXT NOT NULL,
    amount           BIGINT NOT NULL,                  -- kopecks
    billing_period   TEXT NOT NULL,
    next_charge_date TIMESTAMPTZ NOT NULL,
    category_id      UUID REFERENCES category(id),
    is_deleted       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_subscription_family ON subscription(family_id) WHERE is_deleted = FALSE;

-- Refresh tokens: for "logout everywhere" (see § 6.1, ADR-0005) ------

CREATE TABLE refresh_token (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES app_user(id),
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_refresh_token_user ON refresh_token(user_id) WHERE revoked_at IS NULL;
CREATE INDEX idx_refresh_token_hash ON refresh_token(token_hash);

-- Family invites: single-use tokens (see ADR-0005) -------------------

CREATE TABLE family_invite (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id        UUID NOT NULL REFERENCES family(id),
    invited_by       UUID NOT NULL REFERENCES app_user(id),
    invited_email    TEXT NOT NULL,
    invite_token     TEXT NOT NULL UNIQUE,
    expires_at       TIMESTAMPTZ NOT NULL,
    accepted_at      TIMESTAMPTZ,
    accepted_by      UUID REFERENCES app_user(id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_family_invite_family ON family_invite(family_id);
