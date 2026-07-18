package mymoney.domain.usecase.account

import mymoney.domain.model.Account
import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository

class ListAccountsUseCase(private val accounts: AccountRepository) {
    suspend fun execute(ctx: UserContext, includeArchived: Boolean = false): List<Account> =
        accounts.listByFamily(ctx.familyId, includeArchived = includeArchived)
}
