package mymoney.domain.usecase.account

import kotlinx.datetime.Clock
import mymoney.domain.model.Account
import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository
import java.util.UUID

class ArchiveAccountUseCase(
    private val accounts: AccountRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(ctx: UserContext, id: UUID, archived: Boolean): Account {
        val existing = accounts.getOwned(ctx, id)
        if (existing.isArchived == archived) return existing
        val updated = existing.copy(isArchived = archived, updatedAt = clock.now())
        return accounts.update(updated)
    }
}
