package mymoney.domain.usecase.transaction

import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Account
import mymoney.domain.model.Category
import mymoney.domain.model.CategoryType
import mymoney.domain.model.Transaction
import mymoney.domain.model.TransactionType
import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository
import mymoney.domain.repository.CategoryRepository
import mymoney.domain.repository.TransactionRepository
import java.util.UUID

internal suspend fun TransactionRepository.getOwned(ctx: UserContext, id: UUID): Transaction {
    val tx = findById(id) ?: throw NotFoundException("transaction", id.toString())
    if (tx.familyId != ctx.familyId) throw ForbiddenException("transaction belongs to another family")
    if (tx.isDeleted) throw NotFoundException("transaction", id.toString())
    return tx
}

internal suspend fun AccountRepository.requireOwnedActive(
    ctx: UserContext,
    id: UUID,
    fieldName: String,
): Account {
    val acc = findById(id)
        ?: throw ValidationException("account not found", mapOf("field" to fieldName, "id" to id.toString()))
    if (acc.familyId != ctx.familyId) throw ForbiddenException("account belongs to another family")
    if (acc.isDeleted) throw ValidationException("account is deleted", mapOf("field" to fieldName))
    if (acc.isArchived) throw ValidationException("account is archived", mapOf("field" to fieldName))
    return acc
}

internal suspend fun CategoryRepository.requireOwnedForTransaction(
    ctx: UserContext,
    id: UUID,
    txType: TransactionType,
): Category {
    val cat = findById(id)
        ?: throw ValidationException("category not found", mapOf("field" to "categoryId", "id" to id.toString()))
    if (cat.familyId != ctx.familyId) throw ForbiddenException("category belongs to another family")
    if (cat.isDeleted) throw ValidationException("category is deleted", mapOf("field" to "categoryId"))
    val expected = when (txType) {
        TransactionType.INCOME -> CategoryType.INCOME
        TransactionType.EXPENSE -> CategoryType.EXPENSE
        TransactionType.TRANSFER ->
            throw ValidationException(
                "transfer transactions must not carry a category",
                mapOf("field" to "categoryId"),
            )
    }
    if (cat.type != expected) {
        throw ValidationException(
            "category type does not match transaction type",
            mapOf("field" to "categoryId", "expected" to expected.name, "actual" to cat.type.name),
        )
    }
    return cat
}

internal fun validateTransferShape(
    type: TransactionType,
    accountId: UUID,
    targetAccountId: UUID?,
    categoryId: UUID?,
) {
    if (type == TransactionType.TRANSFER) {
        if (targetAccountId == null) {
            throw ValidationException("transfer requires targetAccountId", mapOf("field" to "targetAccountId"))
        }
        if (targetAccountId == accountId) {
            throw ValidationException(
                "transfer must move between distinct accounts",
                mapOf("field" to "targetAccountId"),
            )
        }
        if (categoryId != null) {
            throw ValidationException("transfer must not carry a category", mapOf("field" to "categoryId"))
        }
    } else {
        if (targetAccountId != null) {
            throw ValidationException(
                "only transfers may set targetAccountId",
                mapOf("field" to "targetAccountId"),
            )
        }
    }
}

internal fun validateAmount(amountKopecks: Long) {
    if (amountKopecks <= 0) {
        throw ValidationException(
            "amount must be positive (in kopecks); type determines direction",
            mapOf("field" to "amount"),
        )
    }
}
