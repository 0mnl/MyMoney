package mymoney.domain.repository

import mymoney.domain.model.Account
import java.util.UUID

interface AccountRepository {
    suspend fun create(account: Account): Account
    suspend fun findById(id: UUID): Account?
    suspend fun listByFamily(familyId: UUID, includeArchived: Boolean = false): List<Account>
    suspend fun update(account: Account): Account
    suspend fun softDelete(id: UUID)
}
