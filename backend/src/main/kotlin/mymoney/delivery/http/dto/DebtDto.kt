package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import mymoney.domain.model.Debt

@Serializable
data class DebtDto(
    val id: String,
    val familyId: String,
    val counterpartyName: String,
    val direction: String,
    val amount: Long,
    val dueDate: Instant? = null,
    val status: String,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class CreateDebtRequest(
    val id: String,                    // client-generated UUID
    val counterpartyName: String,
    val direction: String,             // 'I_OWE' | 'OWED_TO_ME'
    val amount: Long,                  // kopecks
    val dueDate: Instant? = null,
)

@Serializable
data class UpdateDebtRequest(
    val counterpartyName: String,
    val amount: Long,
    val dueDate: Instant? = null,
    val status: String,                // 'OPEN' | 'CLOSED'
)

fun Debt.toDto() = DebtDto(
    id = id.toString(),
    familyId = familyId.toString(),
    counterpartyName = counterpartyName,
    direction = direction.name,
    amount = amountKopecks,
    dueDate = dueDate,
    status = status.name,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)
