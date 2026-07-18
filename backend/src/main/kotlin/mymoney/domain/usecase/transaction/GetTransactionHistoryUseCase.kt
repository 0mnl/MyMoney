package mymoney.domain.usecase.transaction

import mymoney.domain.model.TransactionHistoryEntry
import mymoney.domain.model.UserContext
import mymoney.domain.repository.TransactionHistoryRepository
import mymoney.domain.repository.TransactionRepository
import java.util.UUID

class GetTransactionHistoryUseCase(
    private val transactions: TransactionRepository,
    private val history: TransactionHistoryRepository,
) {
    suspend fun execute(ctx: UserContext, transactionId: UUID): List<TransactionHistoryEntry> {
        // Even though the delete flow is soft, we still allow reading history
        // of a deleted transaction — but only for authorized family members.
        val tx = transactions.findById(transactionId)
            ?: throw mymoney.domain.errors.NotFoundException("transaction", transactionId.toString())
        if (tx.familyId != ctx.familyId) {
            throw mymoney.domain.errors.ForbiddenException("transaction belongs to another family")
        }
        return history.listByTransaction(transactionId)
    }
}
