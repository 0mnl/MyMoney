package mymoney.domain.usecase.account

import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.Account
import mymoney.domain.model.UserContext
import mymoney.domain.repository.AccountRepository
import java.util.UUID

/**
 * Fetches an account and enforces family ownership in one place so every use
 * case gets the same check. Not exported outside the account package.
 */
internal suspend fun AccountRepository.getOwned(ctx: UserContext, id: UUID): Account {
    val account = findById(id) ?: throw NotFoundException("account", id.toString())
    if (account.familyId != ctx.familyId) throw ForbiddenException("account belongs to another family")
    if (account.isDeleted) throw NotFoundException("account", id.toString())
    return account
}
