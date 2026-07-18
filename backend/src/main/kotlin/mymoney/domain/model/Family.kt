package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

data class Family(
    val id: UUID,
    val name: String,
    val createdAt: Instant,
    val updatedAt: Instant,
    val isDeleted: Boolean = false,
)

data class FamilyMember(
    val id: UUID,
    val familyId: UUID,
    val userId: UUID,
    val role: FamilyRole,
    val joinedAt: Instant,
    val isDeleted: Boolean = false,
)
