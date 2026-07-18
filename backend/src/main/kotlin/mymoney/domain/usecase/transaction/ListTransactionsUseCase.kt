package mymoney.domain.usecase.transaction

import kotlinx.datetime.Instant
import mymoney.domain.model.Transaction
import mymoney.domain.model.UserContext
import mymoney.domain.repository.TransactionRepository
import java.util.UUID

class ListTransactionsUseCase(private val transactions: TransactionRepository) {
    suspend fun execute(
        ctx: UserContext,
        accountId: UUID? = null,
        categoryId: UUID? = null,
        from: Instant? = null,
        to: Instant? = null,
        limit: Int = 100,
        offset: Long = 0,
    ): List<Transaction> = transactions.list(
        familyId = ctx.familyId,
        accountId = accountId,
        categoryId = categoryId,
        from = from,
        to = to,
        limit = limit.coerceIn(1, 500),
        offset = offset.coerceAtLeast(0),
    )
}
