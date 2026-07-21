package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Subscription — регулярный платёж (напр. Netflix, ЖКХ). Bible §18 №3
 * не детализирует напоминания и обработку отмены — на MVP храним только
 * периодичность + дату следующего списания. Пуш-напоминания и авто-
 * генерация транзакций — за пределами MVP.
 */
enum class SubscriptionPeriod { WEEKLY, MONTHLY, YEARLY }

data class Subscription(
    val id: UUID,
    val familyId: UUID,
    val name: String,
    val amountKopecks: Long,
    val billingPeriod: SubscriptionPeriod,
    val nextChargeDate: Instant,
    val categoryId: UUID? = null,
    val isDeleted: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
