-- MyMoney V3 — подтверждение email при регистрации.
-- Регистрация больше не выдаёт токены сразу: пользователь создаётся с
-- email_verified = FALSE, получает 6-значный код и обменивает его на сессию
-- через POST /v1/auth/verify-email.
--
-- Существующие пользователи backfill-ятся в TRUE: они зарегистрировались до
-- появления проверки и не должны потерять доступ.

ALTER TABLE app_user
    ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;

-- Every row that exists when this migration runs predates the check, so it is
-- grandfathered in. New rows keep the FALSE default.
UPDATE app_user SET email_verified = TRUE;

-- Коды подтверждения. Хранится только хэш (SHA-256) — сам код существует
-- лишь в письме, как и refresh-токены в refresh_token.
CREATE TABLE IF NOT EXISTS email_verification_code (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    code_hash   TEXT NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    attempts    INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Поиск активного кода пользователя — единственный горячий запрос.
CREATE INDEX IF NOT EXISTS idx_email_verification_code_active
    ON email_verification_code(user_id, created_at DESC)
    WHERE consumed_at IS NULL;
