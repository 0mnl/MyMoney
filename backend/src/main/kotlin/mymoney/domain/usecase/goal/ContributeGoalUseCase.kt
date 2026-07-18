package mymoney.domain.usecase.goal

import kotlinx.datetime.Clock
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Goal
import mymoney.domain.model.UserContext
import mymoney.domain.repository.GoalRepository
import java.util.UUID

/**
 * Пополнить (deposit=true) или снять (deposit=false) сумму с цели.
 * Отдельный usecase, чтобы currentAmount не путался с редактированием
 * "паспорта" цели и чтобы валидация была симметричной.
 */
class ContributeGoalUseCase(
    private val goals: GoalRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        amountKopecks: Long,
        deposit: Boolean,
    ): Goal {
        validatePositive(amountKopecks, "amount")
        val existing = goals.getOwned(ctx, id)
        val newCurrent = if (deposit) {
            existing.currentAmountKopecks + amountKopecks
        } else {
            val candidate = existing.currentAmountKopecks - amountKopecks
            if (candidate < 0) {
                throw ValidationException(
                    "cannot withdraw more than current amount",
                    mapOf("field" to "amount"),
                )
            }
            candidate
        }
        val updated = existing.copy(
            currentAmountKopecks = newCurrent,
            updatedAt = clock.now(),
        )
        return goals.update(updated)
    }
}
