package mymoney.domain.repository

import kotlinx.datetime.Instant
import mymoney.domain.model.Budget
import mymoney.domain.model.BudgetPeriodType
import java.util.UUID

interface BudgetRepository {
    suspend fun create(budget: Budget): Budget

    suspend fun findById(id: UUID): Budget?

    suspend fun findExisting(
        familyId: UUID,
        categoryId: UUID,
        periodType: BudgetPeriodType,
        periodStart: Instant,
    ): Budget?

    suspend fun list(
        familyId: UUID,
        periodType: BudgetPeriodType? = null,
        periodStart: Instant? = null,
    ): List<Budget>

    suspend fun update(budget: Budget): Budget

    suspend fun softDelete(id: UUID, now: Instant)

    /**
     * Просуммировать все расходы по (family, category, [from, to]) — используется
     * для расчёта прогресса бюджета. Учитываются только не-удалённые EXPENSE.
     */
    suspend fun sumExpenses(
        familyId: UUID,
        categoryId: UUID,
        from: Instant,
        to: Instant,
    ): Long
}
