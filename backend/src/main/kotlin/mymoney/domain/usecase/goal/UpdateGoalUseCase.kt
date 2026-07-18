package mymoney.domain.usecase.goal

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.domain.model.Goal
import mymoney.domain.model.UserContext
import mymoney.domain.repository.GoalRepository
import java.util.UUID

/**
 * Меняет "паспорт" цели: имя, целевую сумму, дату. currentAmount отдельно
 * через deposit/withdraw, чтобы клиент не мог случайно затереть накопленное.
 */
class UpdateGoalUseCase(
    private val goals: GoalRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        name: String,
        targetAmountKopecks: Long,
        targetDate: Instant?,
    ): Goal {
        validateGoalName(name)
        validatePositive(targetAmountKopecks, "targetAmount")
        val existing = goals.getOwned(ctx, id)
        val updated = existing.copy(
            name = name.trim(),
            targetAmountKopecks = targetAmountKopecks,
            targetDate = targetDate,
            updatedAt = clock.now(),
        )
        return goals.update(updated)
    }
}
