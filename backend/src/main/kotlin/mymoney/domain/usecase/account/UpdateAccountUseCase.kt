package mymoney.domain.usecase.account

import kotlinx.datetime.Clock
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Account
import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository
import java.util.UUID

class UpdateAccountUseCase(
    private val accounts: AccountRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        name: String,
        type: String,
        currency: String,
        initialBalanceKopecks: Long,
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

        val existing = accounts.getOwned(ctx, id)
        val updated = existing.copy(
            name = name.trim(),
            type = type.trim(),
            currency = currency,
            initialBalanceKopecks = initialBalanceKopecks,
            creditLimitKopecks = creditLimitKopecks,
            updatedAt = clock.now(),
        )
        return accounts.update(updated)
    }
}
