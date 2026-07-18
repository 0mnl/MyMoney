package mymoney.domain.repository

import mymoney.domain.model.Family
import mymoney.domain.model.FamilyMember
import mymoney.domain.model.FamilyRole
import java.util.UUID

interface FamilyRepository {
    suspend fun create(family: Family): Family
    suspend fun findById(id: UUID): Family?
    suspend fun rename(id: UUID, newName: String): Family
    suspend fun softDelete(id: UUID)
}

interface FamilyMemberRepository {
    suspend fun add(member: FamilyMember): FamilyMember
    suspend fun findByUserAndFamily(userId: UUID, familyId: UUID): FamilyMember?
    suspend fun listByUser(userId: UUID): List<FamilyMember>
    suspend fun listByFamily(familyId: UUID): List<FamilyMember>
    suspend fun updateRole(memberId: UUID, role: FamilyRole): FamilyMember
    suspend fun softDelete(memberId: UUID)
}
