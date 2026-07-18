package mymoney.domain.usecase.transaction

import mymoney.domain.model.UserContext
import mymoney.domain.repository.TransactionRepository
import java.util.UUID

/**
 * Soft-deletes a transaction. The repository additionally records a history
 * snapshot so the row is recoverable if the deletion turns out to be a
 * mistake (see ADR-0004).
 */
class DeleteTransactionUseCase(private val transactions: TransactionRepository) {
    suspend fun execute(ctx: UserContext, id: UUID) {
        transactions.getOwned(ctx, id)
        transactions.softDelete(id, changedBy = ctx.userId)
    }
}
