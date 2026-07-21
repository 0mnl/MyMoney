package mymoney.domain.repository

import mymoney.domain.model.Debt
import java.util.UUID

interface DebtRepository {
    suspend fun create(debt: Debt): Debt
    suspend fun findById(id: UUID): Debt?
    suspend fun list(familyId: UUID, openOnly: Boolean = false): List<Debt>
    suspend fun update(debt: Debt): Debt
    suspend fun softDelete(id: UUID)
}
