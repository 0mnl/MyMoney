package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import mymoney.domain.model.Subscription

@Serializable
data class SubscriptionDto(
    val id: String,
    val familyId: String,
    val name: String,
    val amount: Long,                  // kopecks
    val billingPeriod: String,         // 'WEEKLY' | 'MONTHLY' | 'YEARLY'
    val nextChargeDate: Instant,
    val categoryId: String? = null,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class CreateSubscriptionRequest(
    val id: String,
    val name: String,
    val amount: Long,
    val billingPeriod: String,
    val nextChargeDate: Instant,
    val categoryId: String? = null,
)

@Serializable
data class UpdateSubscriptionRequest(
    val name: String,
    val amount: Long,
    val billingPeriod: String,
    val nextChargeDate: Instant,
    val categoryId: String? = null,
)

fun Subscription.toDto() = SubscriptionDto(
    id = id.toString(),
    familyId = familyId.toString(),
    name = name,
    amount = amountKopecks,
    billingPeriod = billingPeriod.name,
    nextChargeDate = nextChargeDate,
    categoryId = categoryId?.toString(),
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)
