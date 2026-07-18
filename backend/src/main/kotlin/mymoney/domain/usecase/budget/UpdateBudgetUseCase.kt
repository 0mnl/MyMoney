package mymoney.domain.usecase.budget

import kotlinx.datetime.Clock
import mymoney.domain.model.Budget
import mymoney.domain.model.UserContext
import mymoney.domain.repository.BudgetRepository
import java.util.UUID

/**
 * Обновляет только сумму плана. Смена категории/периода запрещена — это уже
 * другой бюджет; для смены пользователь удаляет старый и создаёт новый.
 */
class UpdateBudgetUseCase(
    private val budgets: BudgetRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        plannedAmountKopecks: Long,
    ): Budget {
        validateBudgetAmount(plannedAmountKopecks)
        val existing = budgets.getOwned(ctx, id)
        val updated = existing.copy(
            plannedAmountKopecks = plannedAmountKopecks,
            updatedAt = clock.now(),
        )
        return budgets.update(updated)
    }
}
