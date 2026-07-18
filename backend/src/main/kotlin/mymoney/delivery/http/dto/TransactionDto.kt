package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.Json
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Transaction
import mymoney.domain.model.TransactionHistoryEntry
import mymoney.domain.model.TransactionType

@Serializable
data class TransactionDto(
    val id: String,
    val familyId: String,
    val accountId: String,
    val categoryId: String?,
    val type: String,                    // INCOME | EXPENSE | TRANSFER
    val targetAccountId: String?,
    val amount: Long,                    // kopecks
    val currency: String,
    val occurredAt: Instant,
    val comment: String?,
    val attachmentPhotoPath: String?,
    val createdBy: String,
    val createdAt: Instant,
    val updatedAt: Instant,
    val isDeleted: Boolean,
)

@Serializable
data class CreateTransactionRequest(
    val id: String,                      // client-generated UUID (ADR-0005)
    val accountId: String,
    val type: String,
    val amount: Long,
    val occurredAt: Instant,
    val currency: String = "RUB",
    val categoryId: String? = null,
    val targetAccountId: String? = null,
    val comment: String? = null,
    val attachmentPhotoPath: String? = null,
)

@Serializable
data class UpdateTransactionRequest(
    val accountId: String,
    val type: String,
    val amount: Long,
    val occurredAt: Instant,
    val currency: String,
    val categoryId: String? = null,
    val targetAccountId: String? = null,
    val comment: String? = null,
    val attachmentPhotoPath: String? = null,
)

@Serializable
data class TransactionHistoryEntryDto(
    val id: String,
    val transactionId: String,
    val snapshot: JsonElement,
    val changedBy: String,
    val changedAt: Instant,
)

fun Transaction.toDto() = TransactionDto(
    id = id.toString(),
    familyId = familyId.toString(),
    accountId = accountId.toString(),
    categoryId = categoryId?.toString(),
    type = type.name,
    targetAccountId = targetAccountId?.toString(),
    amount = amountKopecks,
    currency = currency,
    occurredAt = occurredAt,
    comment = comment,
    attachmentPhotoPath = attachmentPhotoPath,
    createdBy = createdBy.toString(),
    createdAt = createdAt,
    updatedAt = updatedAt,
    isDeleted = isDeleted,
)

fun TransactionHistoryEntry.toDto() = TransactionHistoryEntryDto(
    id = id.toString(),
    transactionId = transactionId.toString(),
    snapshot = Json.parseToJsonElement(snapshotJson),
    changedBy = changedBy.toString(),
    changedAt = changedAt,
)

fun parseTransactionType(raw: String): TransactionType = try {
    TransactionType.valueOf(raw.uppercase())
} catch (_: IllegalArgumentException) {
    throw ValidationException(
        "invalid transaction type: expected INCOME, EXPENSE or TRANSFER",
        mapOf("field" to "type", "value" to raw),
    )
}
