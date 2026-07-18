package mymoney.domain.usecase.goal

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.domain.errors.ConflictException
import mymoney.domain.model.Goal
import mymoney.domain.model.UserContext
import mymoney.domain.repository.GoalRepository
import java.util.UUID

class CreateGoalUseCase(
    private val goals: GoalRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        name: String,
        targetAmountKopecks: Long,
        currentAmountKopecks: Long = 0L,
        targetDate: Instant? = null,
    ): Goal {
        validateGoalName(name)
        validatePositive(targetAmountKopecks, "targetAmount")
        validateNonNegative(currentAmountKopecks, "currentAmount")

        goals.findById(id)?.let {
            throw ConflictException("GOAL_ID_TAKEN", "Goal with this id already exists")
        }

        val now = clock.now()
        return goals.create(
            Goal(
                id = id,
                familyId = ctx.familyId,
                name = name.trim(),
                targetAmountKopecks = targetAmountKopecks,
                currentAmountKopecks = currentAmountKopecks,
                targetDate = targetDate,
                createdAt = now,
                updatedAt = now,
            ),
        )
    }
}
