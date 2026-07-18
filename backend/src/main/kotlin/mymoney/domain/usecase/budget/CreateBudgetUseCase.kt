package mymoney.domain.usecase.budget

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Budget
import mymoney.domain.model.BudgetPeriodType
import mymoney.domain.model.CategoryType
import mymoney.domain.model.UserContext
import mymoney.domain.repository.BudgetRepository
import mymoney.domain.repository.CategoryRepository
import mymoney.domain.usecase.category.getOwned
import java.util.UUID

class CreateBudgetUseCase(
    private val budgets: BudgetRepository,
    private val categories: CategoryRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        categoryId: UUID,
        periodType: BudgetPeriodType,
        periodStart: Instant,
        plannedAmountKopecks: Long,
    ): Budget {
        validateBudgetAmount(plannedAmountKopecks)

        // Проверим что категория расходная и принадлежит семье
        val category = categories.getOwned(ctx, categoryId)
        if (category.type != CategoryType.EXPENSE) {
            throw ValidationException(
                "budget can be set only for EXPENSE categories",
                mapOf("field" to "categoryId"),
            )
        }

        budgets.findById(id)?.let {
            throw ConflictException("BUDGET_ID_TAKEN", "Budget with this id already exists")
        }
        budgets.findExisting(ctx.familyId, categoryId, periodType, periodStart)?.let {
            throw ConflictException(
                "BUDGET_EXISTS",
                "Budget already exists for this category and period",
            )
        }

        val now = clock.now()
        return budgets.create(
            Budget(
                id = id,
                familyId = ctx.familyId,
                categoryId = categoryId,
                periodType = periodType,
                periodStart = periodStart,
                plannedAmountKopecks = plannedAmountKopecks,
                createdAt = now,
                updatedAt = now,
            ),
        )
    }
}
