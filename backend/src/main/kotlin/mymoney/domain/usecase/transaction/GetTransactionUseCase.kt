package mymoney.domain.usecase.transaction

import mymoney.domain.model.Transaction
import mymoney.domain.model.UserContext
import mymoney.domain.repository.TransactionRepository
import java.util.UUID

class GetTransactionUseCase(private val transactions: TransactionRepository) {
    suspend fun execute(ctx: UserContext, id: UUID): Transaction = transactions.getOwned(ctx, id)
}
