package mymoney.domain.usecase.goal

import mymoney.domain.model.Goal
import mymoney.domain.model.UserContext
import mymoney.domain.repository.GoalRepository
import java.util.UUID

class GetGoalUseCase(private val goals: GoalRepository) {
    suspend fun execute(ctx: UserContext, id: UUID): Goal = goals.getOwned(ctx, id)
}
