package mymoney.domain.usecase.goal

import kotlinx.datetime.Clock
import mymoney.domain.model.UserContext
import mymoney.domain.repository.GoalRepository
import java.util.UUID

class DeleteGoalUseCase(
    private val goals: GoalRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(ctx: UserContext, id: UUID) {
        goals.getOwned(ctx, id)
        goals.softDelete(id, clock.now())
    }
}
