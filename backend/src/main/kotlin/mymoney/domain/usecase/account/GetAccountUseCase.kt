package mymoney.domain.usecase.account

import mymoney.domain.model.Account
import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository
import java.util.UUID

class GetAccountUseCase(private val accounts: AccountRepository) {
    suspend fun execute(ctx: UserContext, id: UUID): Account = accounts.getOwned(ctx, id)
}
