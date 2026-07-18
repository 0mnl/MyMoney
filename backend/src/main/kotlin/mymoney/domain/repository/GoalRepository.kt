package mymoney.domain.repository

import kotlinx.datetime.Instant
import mymoney.domain.model.Goal
import java.util.UUID

interface GoalRepository {
    suspend fun create(goal: Goal): Goal

    suspend fun findById(id: UUID): Goal?

    suspend fun list(familyId: UUID): List<Goal>

    suspend fun update(goal: Goal): Goal

    suspend fun softDelete(id: UUID, now: Instant)
}
