package mymoney.domain.usecase.transaction

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Transaction
import mymoney.domain.model.TransactionType
import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository
import mymoney.domain.repository.CategoryRepository
import mymoney.domain.repository.TransactionRepository
import java.util.UUID

/**
 * Fully replaces the mutable fields of a transaction. The previous state is
 * snapshotted to `transaction_history` atomically inside the repository
 * (см. ADR-0004).
 */
class UpdateTransactionUseCase(
    private val transactions: TransactionRepository,
    private val accounts: AccountRepository,
    private val categories: CategoryRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        accountId: UUID,
        type: TransactionType,
        amountKopecks: Long,
        occurredAt: Instant,
        currency: String,
        categoryId: UUID?,
        targetAccountId: UUID?,
        comment: String?,
        attachmentPhotoPath: String?,
    ): Transaction {
        if (currency != "RUB") {
            throw ValidationException("MVP supports RUB only", mapOf("field" to "currency"))
        }
        validateAmount(amountKopecks)
        validateTransferShape(type, accountId, targetAccountId, categoryId)

        val existing = transactions.getOwned(ctx, id)
        accounts.requireOwnedActive(ctx, accountId, "accountId")
        if (targetAccountId != null) {
            accounts.requireOwnedActive(ctx, targetAccountId, "targetAccountId")
        }
        if (categoryId != null) {
            categories.requireOwnedForTransaction(ctx, categoryId, type)
        }

        val updated = existing.copy(
            accountId = accountId,
            categoryId = categoryId,
            type = type,
            targetAccountId = targetAccountId,
            amountKopecks = amountKopecks,
            currency = currency,
            occurredAt = occurredAt,
            comment = comment?.takeIf { it.isNotBlank() },
            attachmentPhotoPath = attachmentPhotoPath?.takeIf { it.isNotBlank() },
            updatedAt = clock.now(),
        )
        return transactions.update(updated, changedBy = ctx.userId)
    }
}
