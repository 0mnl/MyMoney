package mymoney.domain.usecase.budget

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.plus
import kotlinx.datetime.toInstant
import kotlinx.datetime.toLocalDateTime
import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Budget
import mymoney.domain.model.BudgetPeriodType
import mymoney.domain.model.UserContext
import mymoney.domain.repository.BudgetRepository
import java.util.UUID

internal suspend fun BudgetRepository.getOwned(ctx: UserContext, id: UUID): Budget {
    val b = findById(id) ?: throw NotFoundException("budget", id.toString())
    if (b.familyId != ctx.familyId) throw ForbiddenException("budget belongs to another family")
    if (b.isDeleted) throw NotFoundException("budget", id.toString())
    return b
}

internal fun validateBudgetAmount(amountKopecks: Long) {
    if (amountKopecks <= 0L) {
        throw ValidationException(
            "planned amount must be positive (kopecks)",
            mapOf("field" to "plannedAmount"),
        )
    }
}

/**
 * Возвращает границы периода [start, end) для расчёта прогресса. Границы
 * стабильны для одинакового periodType и стартовой даты, чтобы прогресс
 * считался одинаково на клиенте и сервере. Для WEEK — 7 дней от start;
 * для MONTH/YEAR — календарный шаг в UTC.
 */
internal fun periodEnd(periodType: BudgetPeriodType, periodStart: Instant): Instant {
    val tz = TimeZone.UTC
    val ldt = periodStart.toLocalDateTime(tz)
    return when (periodType) {
        BudgetPeriodType.WEEK -> periodStart.plus(7, DateTimeUnit.DAY, tz)
        BudgetPeriodType.MONTH -> {
            val nextDate = ldt.date.plus(1, DateTimeUnit.MONTH)
            LocalDateTime(nextDate.year, nextDate.monthNumber, nextDate.dayOfMonth, ldt.hour, ldt.minute)
                .toInstant(tz)
        }
        BudgetPeriodType.YEAR -> {
            val nextDate = ldt.date.plus(1, DateTimeUnit.YEAR)
            LocalDateTime(nextDate.year, nextDate.monthNumber, nextDate.dayOfMonth, ldt.hour, ldt.minute)
                .toInstant(tz)
        }
    }
}
