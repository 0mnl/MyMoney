package mymoney.domain.usecase.account

import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository
import java.util.UUID

/**
 * Soft-deletes an account (see § 25.2 Bible — soft delete for every user
 * entity so sync can propagate deletions). Existing transactions on this
 * account are kept as-is; the UI is expected to hide deleted accounts and
 * their transactions from listings.
 */
class DeleteAccountUseCase(
    private val accounts: AccountRepository,
) {
    suspend fun execute(ctx: UserContext, id: UUID) {
        accounts.getOwned(ctx, id)              // enforces ownership + existence
        accounts.softDelete(id)
    }
}
