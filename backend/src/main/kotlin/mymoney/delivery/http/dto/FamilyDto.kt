package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import mymoney.domain.model.FamilyMember

@Serializable
data class InviteRequest(val email: String)

@Serializable
data class InviteResponse(
    val inviteToken: String,
    val expiresAt: Instant,
)

@Serializable
data class AcceptInviteRequest(val inviteToken: String)

@Serializable
data class AcceptInviteResponse(val familyId: String)

@Serializable
data class FamilyMemberDto(
    val id: String,
    val familyId: String,
    val userId: String,
    val role: String,
    val joinedAt: Instant,
)

@Serializable
data class FamilyMembersResponse(val members: List<FamilyMemberDto>)

fun FamilyMember.toDto() = FamilyMemberDto(
    id = id.toString(),
    familyId = familyId.toString(),
    userId = userId.toString(),
    role = role.name,
    joinedAt = joinedAt,
)
