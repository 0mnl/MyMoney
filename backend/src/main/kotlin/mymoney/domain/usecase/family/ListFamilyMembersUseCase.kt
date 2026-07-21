package mymoney.domain.usecase.family

import mymoney.domain.model.FamilyMember
import mymoney.domain.repository.FamilyMemberRepository
import java.util.UUID

class ListFamilyMembersUseCase(private val members: FamilyMemberRepository) {
    suspend fun execute(familyId: UUID): List<FamilyMember> = members.listByFamily(familyId)
}
