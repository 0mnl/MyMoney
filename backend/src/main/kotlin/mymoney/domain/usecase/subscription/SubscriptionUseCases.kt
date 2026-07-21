package mymoney.domain.usecase.subscription

import kotlinx.datetime.Clock
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.datetime.plus
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Subscription
import mymoney.domain.model.SubscriptionPeriod
import mymoney.domain.model.UserContext
import mymoney.domain.repository.SubscriptionRepository
import java.util.UUID

class CreateSubscriptionUseCase(
    private val repo: SubscriptionRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        name: String,
        amountKopecks: Long,
        billingPeriod: SubscriptionPeriod,
        nextChargeDate: Instant,
        categoryId: UUID?,
    ): Subscription {
        if (name.isBlank()) throw ValidationException("name is required")
        if (amountKopecks <= 0) throw ValidationException("amount must be > 0")
        repo.findById(id)?.let { throw ConflictException("SUBSCRIPTION_ID_TAKEN", "id already exists") }
        val now = clock.now()
        return repo.create(
            Subscription(
                id = id,
                familyId = ctx.familyId,
                name = name.trim(),
                amountKopecks = amountKopecks,
                billingPeriod = billingPeriod,
                nextChargeDate = nextChargeDate,
                categoryId = categoryId,
                createdAt = now,
                updatedAt = now,
            ),
        )
    }
}

class ListSubscriptionsUseCase(private val repo: SubscriptionRepository) {
    suspend fun execute(ctx: UserContext): List<Subscription> = repo.list(ctx.familyId)
}

class GetSubscriptionUseCase(private val repo: SubscriptionRepository) {
    suspend fun execute(ctx: UserContext, id: UUID): Subscription {
        val s = repo.findById(id) ?: throw NotFoundException("subscription", id.toString())
        if (s.familyId != ctx.familyId) throw ForbiddenException("Subscription belongs to another family")
        return s
    }
}

class UpdateSubscriptionUseCase(
    private val repo: SubscriptionRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        name: String,
        amountKopecks: Long,
        billingPeriod: SubscriptionPeriod,
        nextChargeDate: Instant,
        categoryId: UUID?,
    ): Subscription {
        val existing = repo.findById(id) ?: throw NotFoundException("subscription", id.toString())
        if (existing.familyId != ctx.familyId) throw ForbiddenException("Subscription belongs to another family")
        if (name.isBlank()) throw ValidationException("name is required")
        if (amountKopecks <= 0) throw ValidationException("amount must be > 0")
        return repo.update(
            existing.copy(
                name = name.trim(),
                amountKopecks = amountKopecks,
                billingPeriod = billingPeriod,
                nextChargeDate = nextChargeDate,
                categoryId = categoryId,
                updatedAt = clock.now(),
            ),
        )
    }
}

class DeleteSubscriptionUseCase(private val repo: SubscriptionRepository) {
    suspend fun execute(ctx: UserContext, id: UUID) {
        val existing = repo.findById(id) ?: throw NotFoundException("subscription", id.toString())
        if (existing.familyId != ctx.familyId) throw ForbiddenException("Subscription belongs to another family")
        repo.softDelete(id)
    }
}

/**
 * Продвигает nextChargeDate на один период вперёд — сценарий "оплатил, следующее
 * списание через месяц/неделю/год". Не создаёт транзакцию (это отдельный сценарий).
 */
class AdvanceSubscriptionUseCase(
    private val repo: SubscriptionRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(ctx: UserContext, id: UUID): Subscription {
        val existing = repo.findById(id) ?: throw NotFoundException("subscription", id.toString())
        if (existing.familyId != ctx.familyId) throw ForbiddenException("Subscription belongs to another family")
        val nextDate = when (existing.billingPeriod) {
            SubscriptionPeriod.WEEKLY -> existing.nextChargeDate.plus(7, DateTimeUnit.DAY, TimeZone.UTC)
            SubscriptionPeriod.MONTHLY -> existing.nextChargeDate.plus(1, DateTimeUnit.MONTH, TimeZone.UTC)
            SubscriptionPeriod.YEARLY -> existing.nextChargeDate.plus(1, DateTimeUnit.YEAR, TimeZone.UTC)
        }
        return repo.update(existing.copy(nextChargeDate = nextDate, updatedAt = clock.now()))
    }
}
