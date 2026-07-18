package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Budget — планируемая сумма на категорию за период (WEEK/MONTH/YEAR).
 * Progress вычисляется отдельно из транзакций категории за окно
 * [periodStart, periodStart + period_type).
 */
data class Budget(
    val id: UUID,
    val familyId: UUID,
    val categoryId: UUID,
    val periodType: BudgetPeriodType,
    val periodStart: Instant,
    val plannedAmountKopecks: Long,
    val createdAt: Instant,
    val updatedAt: Instant,
    val isDeleted: Boolean = false,
)

/**
 * Просчитанный прогресс бюджета — планируемая сумма, потраченная сумма
 * (в копейках) за период и признак превышения. Не хранится в БД.
 */
data class BudgetProgress(
    val budget: Budget,
    val spentAmountKopecks: Long,
    val remainingAmountKopecks: Long,
    val progressPercent: Int,
    val isOverspent: Boolean,
)
