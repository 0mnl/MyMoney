package mymoney.domain.usecase.budget

import mymoney.domain.model.Budget
import mymoney.domain.model.UserContext
import mymoney.domain.repository.BudgetRepository
import java.util.UUID

class GetBudgetUseCase(private val budgets: BudgetRepository) {
    suspend fun execute(ctx: UserContext, id: UUID): Budget = budgets.getOwned(ctx, id)
}
