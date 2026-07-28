-- MyMoney V2 — приводит схему в соответствие с Bible v2 §13.
-- 1. account.credit_limit — доступный остаток кредитки (§7.2, §12).
-- 2. debt.interest_rate — годовая ставка по долгу (§7.7, §20 п.7).
-- 3. debt_payment — график платежей по долгу (§13).
-- Все новые столбцы nullable/с DEFAULT — существующие строки не ломаются.

ALTER TABLE account
    ADD COLUMN IF NOT EXISTS credit_limit BIGINT;          -- kopecks, NULL для не-кредитных счетов

ALTER TABLE debt
    ADD COLUMN IF NOT EXISTS interest_rate NUMERIC(5,2) NOT NULL DEFAULT 0;  -- annual %, ADR-0002 не применяется — это ставка, не сумма

CREATE TABLE IF NOT EXISTS debt_payment (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    debt_id        UUID NOT NULL REFERENCES debt(id),
    due_date       TIMESTAMPTZ NOT NULL,
    planned_amount BIGINT NOT NULL,                    -- kopecks
    is_paid        BOOLEAN NOT NULL DEFAULT FALSE,
    paid_at        TIMESTAMPTZ,
    transaction_id UUID REFERENCES transaction(id),    -- операция погашения (§7.7)
    is_deleted     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_debt_payment_debt ON debt_payment(debt_id) WHERE is_deleted = FALSE;
