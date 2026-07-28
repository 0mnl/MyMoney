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
    val interestRate: Double = 0.0,   // годовая ставка, % (Bible v2 §7.7)
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
    val interestRate: Double = 0.0,
    val dueDate: Instant? = null,
)

@Serializable
data class UpdateDebtRequest(
    val counterpartyName: String,
    val amount: Long,
    val interestRate: Double = 0.0,
    val dueDate: Instant? = null,
    val status: String,                // 'OPEN' | 'CLOSED'
)

fun Debt.toDto() = DebtDto(
    id = id.toString(),
    familyId = familyId.toString(),
    counterpartyName = counterpartyName,
    direction = direction.name,
    amount = amountKopecks,
    interestRate = interestRate,
    dueDate = dueDate,
    status = status.name,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

@Serializable
data class DebtPaymentDto(
    val id: String,
    val debtId: String,
    val dueDate: Instant,
    val plannedAmount: Long,          // kopecks
    val isPaid: Boolean,
    val paidAt: Instant? = null,
    val transactionId: String? = null,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

fun mymoney.domain.model.DebtPayment.toDto() = DebtPaymentDto(
    id = id.toString(),
    debtId = debtId.toString(),
    dueDate = dueDate,
    plannedAmount = plannedAmountKopecks,
    isPaid = isPaid,
    paidAt = paidAt,
    transactionId = transactionId?.toString(),
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)
