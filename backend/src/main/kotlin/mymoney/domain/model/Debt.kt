package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Debt — либо мы кому-то должны (I_OWE), либо нам должны (OWED_TO_ME).
 *
 * По Bible v2 §7.7 в MVP: учитывается годовая ставка ([interestRate]) и
 * график платежей — см. [DebtPayment]. Закрытие через status = CLOSED.
 */
data class Debt(
    val id: UUID,
    val familyId: UUID,
    val counterpartyName: String,
    val direction: DebtDirection,
    val amountKopecks: Long,
    val interestRate: Double = 0.0,       // annual %, NUMERIC(5,2)
    val dueDate: Instant? = null,
    val status: DebtStatus = DebtStatus.OPEN,
    val isDeleted: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)

/**
 * Плановая позиция графика погашения долга (Bible v2 §13).
 * При погашении [transactionId] ссылается на созданную операцию расхода/дохода.
 */
data class DebtPayment(
    val id: UUID,
    val debtId: UUID,
    val dueDate: Instant,
    val plannedAmountKopecks: Long,
    val isPaid: Boolean = false,
    val paidAt: Instant? = null,
    val transactionId: UUID? = null,
    val isDeleted: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
