package mymoney.domain.repository

import kotlinx.datetime.Instant
import mymoney.domain.model.FamilyInvite
import java.util.UUID

interface FamilyInviteRepository {
    suspend fun create(invite: FamilyInvite): FamilyInvite
    suspend fun findByToken(token: String): FamilyInvite?
    suspend fun listPendingByFamily(familyId: UUID): List<FamilyInvite>
    suspend fun markAccepted(id: UUID, acceptedBy: UUID, acceptedAt: Instant): FamilyInvite
}
