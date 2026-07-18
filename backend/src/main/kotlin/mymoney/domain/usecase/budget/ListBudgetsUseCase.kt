package mymoney.domain.usecase.budget

import kotlinx.datetime.Instant
import mymoney.domain.model.Budget
import mymoney.domain.model.BudgetPeriodType
import mymoney.domain.model.UserContext
import mymoney.domain.repository.BudgetRepository

class ListBudgetsUseCase(private val budgets: BudgetRepository) {
    suspend fun execute(
        ctx: UserContext,
        periodType: BudgetPeriodType? = null,
        periodStart: Instant? = null,
    ): List<Budget> = budgets.list(ctx.familyId, periodType, periodStart)
}
