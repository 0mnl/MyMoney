package mymoney.domain.usecase.budget

import mymoney.domain.model.BudgetProgress
import mymoney.domain.model.UserContext
import mymoney.domain.repository.BudgetRepository
import java.util.UUID

/**
 * Прогресс по одному бюджету: сколько потрачено за окно [periodStart, periodEnd).
 * Считается по всем не-удалённым EXPENSE-транзакциям семьи в выбранной
 * категории; результат — чистое вычисление, никаких изменений в БД.
 */
class GetBudgetProgressUseCase(private val budgets: BudgetRepository) {
    suspend fun execute(ctx: UserContext, id: UUID): BudgetProgress {
        val budget = budgets.getOwned(ctx, id)
        val end = periodEnd(budget.periodType, budget.periodStart)
        val spent = budgets.sumExpenses(
            familyId = budget.familyId,
            categoryId = budget.categoryId,
            from = budget.periodStart,
            to = end,
        )
        val remaining = (budget.plannedAmountKopecks - spent)
        val percent = if (budget.plannedAmountKopecks <= 0L) 0
        else ((spent * 100.0 / budget.plannedAmountKopecks).toInt()).coerceAtLeast(0)
        return BudgetProgress(
            budget = budget,
            spentAmountKopecks = spent,
            remainingAmountKopecks = remaining,
            progressPercent = percent,
            isOverspent = spent > budget.plannedAmountKopecks,
        )
    }
}
