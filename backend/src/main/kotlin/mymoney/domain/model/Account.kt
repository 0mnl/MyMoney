package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Account (счёт) — a place where money lives (cash, card, savings, ...).
 * Owner is the whole family, not an individual user (see Bible v2 §10.3).
 *
 * Amounts are BIGINT kopecks — see ADR-0002.
 *
 * [creditLimitKopecks] is non-null only for credit-card accounts (Bible v2 §7.2).
 * Доступный остаток по кредитке = credit_limit − сумма непогашенных расходов.
 */
data class Account(
    val id: UUID,
    val familyId: UUID,
    val name: String,
    val type: String,             // user-defined free-form type, e.g. "cash", "card"
    val currency: String,          // MVP: always "RUB"
    val initialBalanceKopecks: Long,
    val creditLimitKopecks: Long? = null,
    val isArchived: Boolean = false,
    val isDeleted: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
