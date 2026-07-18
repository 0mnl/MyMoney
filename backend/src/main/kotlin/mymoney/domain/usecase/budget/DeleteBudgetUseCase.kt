package mymoney.domain.usecase.budget

import kotlinx.datetime.Clock
import mymoney.domain.model.UserContext
import mymoney.domain.repository.BudgetRepository
import java.util.UUID

class DeleteBudgetUseCase(
    private val budgets: BudgetRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(ctx: UserContext, id: UUID) {
        budgets.getOwned(ctx, id)
        budgets.softDelete(id, clock.now())
    }
}
