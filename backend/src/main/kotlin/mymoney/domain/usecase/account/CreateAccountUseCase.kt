package mymoney.domain.usecase.account

import kotlinx.datetime.Clock
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Account
import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository
import java.util.UUID

class CreateAccountUseCase(
    private val accounts: AccountRepository,
    private val clock: Clock = Clock.System,
) {
    /**
     * Client provides the account [id] (client-generated UUID, see ADR-0005).
     * On duplicate id we throw 409 instead of silently upserting; sync-driven
     * upserts belong to /sync/push and are added in Step 4.
     */
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        name: String,
        type: String,
        currency: String = "RUB",
        initialBalanceKopecks: Long = 0,
        creditLimitKopecks: Long? = null,
    ): Account {
        if (name.isBlank()) throw ValidationException("name must not be blank", mapOf("field" to "name"))
        if (type.isBlank()) throw ValidationException("type must not be blank", mapOf("field" to "type"))
        if (currency != "RUB") {
            throw ValidationException(
                "MVP supports RUB only",
                mapOf("field" to "currency", "supported" to "RUB"),
            )
        }
        if (creditLimitKopecks != null && creditLimitKopecks < 0) {
            throw ValidationException(
                "creditLimit must be non-negative",
                mapOf("field" to "creditLimit"),
            )
        }

        accounts.findById(id)?.let {
            throw ConflictException("ACCOUNT_ID_TAKEN", "Account with this id already exists")
        }

        val now = clock.now()
        val account = Account(
            id = id,
            familyId = ctx.familyId,
            name = name.trim(),
            type = type.trim(),
            currency = currency,
            initialBalanceKopecks = initialBalanceKopecks,
            creditLimitKopecks = creditLimitKopecks,
            createdAt = now,
            updatedAt = now,
        )
        return accounts.create(account)
    }
}
