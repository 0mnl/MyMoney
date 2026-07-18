package mymoney.domain.repository

import kotlinx.datetime.Instant
import mymoney.domain.model.Transaction
import mymoney.domain.model.TransactionHistoryEntry
import java.util.UUID

interface TransactionRepository {
    suspend fun create(transaction: Transaction): Transaction

    suspend fun findById(id: UUID): Transaction?

    suspend fun list(
        familyId: UUID,
        accountId: UUID? = null,
        categoryId: UUID? = null,
        from: Instant? = null,
        to: Instant? = null,
        limit: Int = 100,
        offset: Long = 0,
    ): List<Transaction>

    /**
     * Update an existing transaction. Implementations MUST atomically:
     *   1. Snapshot the previous state into transaction_history.
     *   2. Overwrite the row with the new state.
     * This is the audit-trail contract (see § 10.4 Bible, ADR-0004).
     */
    suspend fun update(transaction: Transaction, changedBy: UUID): Transaction

    suspend fun softDelete(id: UUID, changedBy: UUID)
}

interface TransactionHistoryRepository {
    suspend fun listByTransaction(transactionId: UUID): List<TransactionHistoryEntry>
}
