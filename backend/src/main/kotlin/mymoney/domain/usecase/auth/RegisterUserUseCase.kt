package mymoney.domain.usecase.auth

import kotlinx.datetime.Clock
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Family
import mymoney.domain.model.FamilyMember
import mymoney.domain.model.FamilyRole
import mymoney.domain.model.User
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.FamilyRepository
import mymoney.domain.repository.UserRepository
import mymoney.domain.security.PasswordHasher
import mymoney.domain.usecase.category.SeedSystemCategoriesUseCase
import java.util.UUID

/**
 * Registers a new user, provisions a personal family with the user as OWNER,
 * and emails a confirmation code.
 *
 * No tokens are issued here — the account is created with `email_verified =
 * false` and only [VerifyEmailUseCase] turns it into a usable session. That
 * keeps an unconfirmed address from ever reaching the app while still letting
 * us provision the family up front, so confirmation is a single flag flip.
 *
 * This is one of the two places where the server generates entity IDs
 * (see ADR-0005). Elsewhere IDs come from the client.
 */
class RegisterUserUseCase(
    private val users: UserRepository,
    private val families: FamilyRepository,
    private val members: FamilyMemberRepository,
    private val passwordHasher: PasswordHasher,
    private val seedSystemCategories: SeedSystemCategoriesUseCase,
    private val codeIssuer: VerificationCodeIssuer,
    private val clock: Clock = Clock.System,
) {

    suspend fun execute(rawEmail: String, password: String): PendingRegistration {
        val email = normalizeEmail(rawEmail)
        if (!isValidEmail(email)) {
            throw ValidationException("Invalid email", mapOf("field" to "email"))
        }
        if (!isValidPassword(password)) {
            throw ValidationException(
                "Password too short",
                mapOf("field" to "password", "minLength" to "8"),
            )
        }

        val existing = users.findByEmail(email)
        if (existing != null) {
            // An unconfirmed signup is not a conflict — the user most likely
            // lost the first code. Re-issue instead of blocking them out of an
            // address they own but never activated. The issuer's cooldown
            // decides whether a new mail actually goes out, so retrying here
            // cannot be used to flood someone else's inbox.
            if (!users.isEmailVerified(existing.id)) {
                return codeIssuer.issue(existing.id, email).toPending(email)
            }
            throw ConflictException(
                code = "EMAIL_TAKEN",
                msg = "Email already registered",
                details = mapOf("email" to email),
            )
        }

        val now = clock.now()
        val userId = UUID.randomUUID()
        val familyId = UUID.randomUUID()

        val passwordHash = passwordHasher.hash(password)

        users.create(
            User(id = userId, email = email, createdAt = now, updatedAt = now),
            passwordHash,
        )
        families.create(
            Family(id = familyId, name = defaultFamilyName(email), createdAt = now, updatedAt = now),
        )
        members.add(
            FamilyMember(
                id = UUID.randomUUID(),
                familyId = familyId,
                userId = userId,
                role = FamilyRole.OWNER,
                joinedAt = now,
            ),
        )
        seedSystemCategories.execute(familyId)

        return codeIssuer.issue(userId, email).toPending(email)
    }

    private fun defaultFamilyName(email: String) = email.substringBefore('@').ifBlank { "Family" }
}
