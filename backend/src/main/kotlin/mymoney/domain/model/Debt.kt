package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Debt — либо мы кому-то должны (I_OWE), либо нам должны (OWED_TO_ME).
 * Bible §7 / §18 №2 не раскрывает график погашения и % — на MVP храним
 * атомарную сумму и dueDate; закрытие через status = CLOSED.
 */
data class Debt(
    val id: UUID,
    val familyId: UUID,
    val counterpartyName: String,
    val direction: DebtDirection,
    val amountKopecks: Long,
    val dueDate: Instant? = null,
    val status: DebtStatus = DebtStatus.OPEN,
    val isDeleted: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
