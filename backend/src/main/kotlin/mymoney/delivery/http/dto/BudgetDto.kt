package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Budget
import mymoney.domain.model.BudgetPeriodType
import mymoney.domain.model.BudgetProgress

@Serializable
data class BudgetDto(
    val id: String,
    val familyId: String,
    val categoryId: String,
    val periodType: String,               // WEEK | MONTH | YEAR
    val periodStart: Instant,
    val plannedAmount: Long,              // kopecks
    val createdAt: Instant,
    val updatedAt: Instant,
    val isDeleted: Boolean,
)

@Serializable
data class CreateBudgetRequest(
    val id: String,                       // client-generated UUID (ADR-0005)
    val categoryId: String,
    val periodType: String,
    val periodStart: Instant,
    val plannedAmount: Long,
)

@Serializable
data class UpdateBudgetRequest(
    val plannedAmount: Long,
)

@Serializable
data class BudgetProgressDto(
    val budget: BudgetDto,
    val spentAmount: Long,                // kopecks
    val remainingAmount: Long,            // kopecks (can be negative if overspent)
    val progressPercent: Int,
    val isOverspent: Boolean,
)

fun Budget.toDto() = BudgetDto(
    id = id.toString(),
    familyId = familyId.toString(),
    categoryId = categoryId.toString(),
    periodType = periodType.name,
    periodStart = periodStart,
    plannedAmount = plannedAmountKopecks,
    createdAt = createdAt,
    updatedAt = updatedAt,
    isDeleted = isDeleted,
)

fun BudgetProgress.toDto() = BudgetProgressDto(
    budget = budget.toDto(),
    spentAmount = spentAmountKopecks,
    remainingAmount = remainingAmountKopecks,
    progressPercent = progressPercent,
    isOverspent = isOverspent,
)

fun parseBudgetPeriodType(raw: String): BudgetPeriodType = try {
    BudgetPeriodType.valueOf(raw.uppercase())
} catch (_: IllegalArgumentException) {
    throw ValidationException(
        "invalid period type: expected WEEK, MONTH or YEAR",
        mapOf("field" to "periodType", "value" to raw),
    )
}
