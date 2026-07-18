package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import mymoney.domain.model.Goal

@Serializable
data class GoalDto(
    val id: String,
    val familyId: String,
    val name: String,
    val targetAmount: Long,               // kopecks
    val currentAmount: Long,              // kopecks
    val targetDate: Instant?,
    val progressPercent: Int,
    val isCompleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
    val isDeleted: Boolean,
)

@Serializable
data class CreateGoalRequest(
    val id: String,
    val name: String,
    val targetAmount: Long,
    val currentAmount: Long = 0L,
    val targetDate: Instant? = null,
)

@Serializable
data class UpdateGoalRequest(
    val name: String,
    val targetAmount: Long,
    val targetDate: Instant? = null,
)

@Serializable
data class GoalContributionRequest(
    val amount: Long,
)

fun Goal.toDto() = GoalDto(
    id = id.toString(),
    familyId = familyId.toString(),
    name = name,
    targetAmount = targetAmountKopecks,
    currentAmount = currentAmountKopecks,
    targetDate = targetDate,
    progressPercent = progressPercent,
    isCompleted = isCompleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
    isDeleted = isDeleted,
)
