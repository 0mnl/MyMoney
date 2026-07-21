package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

data class FamilyInvite(
    val id: UUID,
    val familyId: UUID,
    val invitedBy: UUID,
    val invitedEmail: String,
    val inviteToken: String,
    val expiresAt: Instant,
    val acceptedAt: Instant? = null,
    val acceptedBy: UUID? = null,
    val createdAt: Instant,
)
