package mymoney.domain.usecase.goal

import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Goal
import mymoney.domain.model.UserContext
import mymoney.domain.repository.GoalRepository
import java.util.UUID

internal suspend fun GoalRepository.getOwned(ctx: UserContext, id: UUID): Goal {
    val g = findById(id) ?: throw NotFoundException("goal", id.toString())
    if (g.familyId != ctx.familyId) throw ForbiddenException("goal belongs to another family")
    if (g.isDeleted) throw NotFoundException("goal", id.toString())
    return g
}

internal fun validatePositive(amountKopecks: Long, field: String) {
    if (amountKopecks <= 0L) {
        throw ValidationException("$field must be positive (kopecks)", mapOf("field" to field))
    }
}

internal fun validateNonNegative(amountKopecks: Long, field: String) {
    if (amountKopecks < 0L) {
        throw ValidationException("$field must be non-negative (kopecks)", mapOf("field" to field))
    }
}

internal fun validateGoalName(name: String) {
    if (name.isBlank()) {
        throw ValidationException("goal name must not be blank", mapOf("field" to "name"))
    }
    if (name.length > 200) {
        throw ValidationException("goal name is too long (max 200)", mapOf("field" to "name"))
    }
}
