package mymoney.domain.usecase.family

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.FamilyInvite
import mymoney.domain.model.FamilyRole
import mymoney.domain.repository.FamilyInviteRepository
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.UserRepository
import mymoney.domain.usecase.auth.isValidEmail
import mymoney.domain.usecase.auth.normalizeEmail
import java.util.UUID
import kotlin.time.Duration.Companion.hours

/**
 * Creates a single-use invite token for adding a second member to a family.
 * Owner-only. MVP: family size hard-capped at 2 (see Bible § 6.7).
 */
class InviteFamilyMemberUseCase(
    private val members: FamilyMemberRepository,
    private val users: UserRepository,
    private val invites: FamilyInviteRepository,
    private val tokenGenerator: InviteTokenGenerator,
    private val clock: Clock = Clock.System,
    private val inviteTtlHours: Long = 72,
) {
    data class Result(val inviteToken: String, val expiresAt: Instant)

    suspend fun execute(inviterUserId: UUID, inviterFamilyId: UUID, rawEmail: String): Result {
        val email = normalizeEmail(rawEmail)
        if (!isValidEmail(email)) {
            throw ValidationException("Invalid email", mapOf("field" to "email"))
        }

        val inviter = members.findByUserAndFamily(inviterUserId, inviterFamilyId)
            ?: throw ForbiddenException("Not a member of this family")
        if (inviter.role != FamilyRole.OWNER) {
            throw ForbiddenException("Only the family owner can invite")
        }

        val active = members.listByFamily(inviterFamilyId)
        if (active.size >= FAMILY_MAX_MEMBERS) {
            throw ConflictException(
                code = "FAMILY_FULL",
                msg = "Family already has $FAMILY_MAX_MEMBERS members (MVP limit)",
            )
        }

        val target = users.findByEmail(email)
            ?: throw NotFoundException("user", email)

        if (target.id == inviterUserId) {
            throw ValidationException("Cannot invite yourself")
        }

        val alreadyMember = members.findByUserAndFamily(target.id, inviterFamilyId)
        if (alreadyMember != null) {
            throw ConflictException("ALREADY_MEMBER", "User is already in this family")
        }

        val now = clock.now()
        val invite = FamilyInvite(
            id = UUID.randomUUID(),
            familyId = inviterFamilyId,
            invitedBy = inviterUserId,
            invitedEmail = email,
            inviteToken = tokenGenerator.generate(),
            expiresAt = now + inviteTtlHours.hours,
            createdAt = now,
        )
        invites.create(invite)
        return Result(inviteToken = invite.inviteToken, expiresAt = invite.expiresAt)
    }

    companion object {
        const val FAMILY_MAX_MEMBERS = 2
    }
}
