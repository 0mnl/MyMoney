package mymoney.domain.usecase.transaction

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Transaction
import mymoney.domain.model.TransactionType
import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository
import mymoney.domain.repository.CategoryRepository
import mymoney.domain.repository.TransactionRepository
import java.util.UUID

class CreateTransactionUseCase(
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
        currency: String = "RUB",
        categoryId: UUID? = null,
        targetAccountId: UUID? = null,
        comment: String? = null,
        attachmentPhotoPath: String? = null,
    ): Transaction {
        if (currency != "RUB") {
            throw ValidationException("MVP supports RUB only", mapOf("field" to "currency"))
        }
        validateAmount(amountKopecks)
        validateTransferShape(type, accountId, targetAccountId, categoryId)

        transactions.findById(id)?.let {
            throw ConflictException("TRANSACTION_ID_TAKEN", "Transaction with this id already exists")
        }

        accounts.requireOwnedActive(ctx, accountId, "accountId")
        if (targetAccountId != null) {
            accounts.requireOwnedActive(ctx, targetAccountId, "targetAccountId")
        }
        if (categoryId != null) {
            categories.requireOwnedForTransaction(ctx, categoryId, type)
        }

        val now = clock.now()
        return transactions.create(
            Transaction(
                id = id,
                familyId = ctx.familyId,
                accountId = accountId,
                categoryId = categoryId,
                type = type,
                targetAccountId = targetAccountId,
                amountKopecks = amountKopecks,
                currency = currency,
                occurredAt = occurredAt,
                comment = comment?.takeIf { it.isNotBlank() },
                attachmentPhotoPath = attachmentPhotoPath?.takeIf { it.isNotBlank() },
                createdBy = ctx.userId,
                createdAt = now,
                updatedAt = now,
            ),
        )
    }
}
