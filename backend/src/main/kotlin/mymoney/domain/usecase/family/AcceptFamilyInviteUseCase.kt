package mymoney.domain.usecase.family

import kotlinx.datetime.Clock
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.FamilyMember
import mymoney.domain.model.FamilyRole
import mymoney.domain.repository.FamilyInviteRepository
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.RefreshTokenRepository
import java.util.UUID

/**
 * Accepts a family invite: moves the accepting user from their personal family
 * into the inviter's family as a MEMBER. Their old membership is soft-deleted.
 *
 * Refresh tokens are revoked because access tokens carry `family_id` — the
 * client must re-login so the new JWT reflects the new family.
 */
class AcceptFamilyInviteUseCase(
    private val invites: FamilyInviteRepository,
    private val members: FamilyMemberRepository,
    private val refreshTokens: RefreshTokenRepository,
    private val clock: Clock = Clock.System,
) {
    data class Result(val familyId: UUID, val previousFamilyId: UUID?)

    suspend fun execute(accepterUserId: UUID, inviteToken: String): Result {
        val invite = invites.findByToken(inviteToken)
            ?: throw NotFoundException("family_invite", "token")

        val now = clock.now()
        if (invite.acceptedAt != null) {
            throw ConflictException("INVITE_ALREADY_USED", "Invite already accepted")
        }
        if (invite.expiresAt <= now) {
            throw ConflictException("INVITE_EXPIRED", "Invite expired")
        }

        val currentMembers = members.listByFamily(invite.familyId)
        if (currentMembers.size >= InviteFamilyMemberUseCase.FAMILY_MAX_MEMBERS) {
            throw ConflictException(
                code = "FAMILY_FULL",
                msg = "Family already has ${InviteFamilyMemberUseCase.FAMILY_MAX_MEMBERS} members",
            )
        }
        if (currentMembers.any { it.userId == accepterUserId }) {
            throw ValidationException("Already a member of this family")
        }

        // Soft-delete any prior single-user family memberships. In MVP a user has
        // at most one; we still loop to keep the invariant correct.
        val prior = members.listByUser(accepterUserId)
        val previousFamilyId = prior.firstOrNull()?.familyId
        prior.forEach { members.softDelete(it.id) }

        members.add(
            FamilyMember(
                id = UUID.randomUUID(),
                familyId = invite.familyId,
                userId = accepterUserId,
                role = FamilyRole.MEMBER,
                joinedAt = now,
            ),
        )

        invites.markAccepted(invite.id, accepterUserId, now)
        refreshTokens.revokeAllForUser(accepterUserId)

        return Result(familyId = invite.familyId, previousFamilyId = previousFamilyId)
    }
}
